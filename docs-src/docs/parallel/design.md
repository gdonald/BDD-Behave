# Parallel Execution: Design

This document describes how `--parallel N` works internally. For the user-facing
guide, see [Parallel Execution](parallel.md).

## Goal

`behave --parallel N` runs a spec suite across `N` worker subprocesses
concurrently. With no flag, `behave` keeps its single-process, single-worker
behavior unchanged.

The design holds to four properties:

- A suite that takes `T` seconds serially takes roughly `T / N` seconds on `N`
  cores, modulo per-worker startup overhead and load imbalance.
- Failure output, summary counts, profile/benchmark sections, exit code,
  and seed reporting stay meaningful and reproducible.
- User code that assumes a fresh process per worker (DB connection per worker,
  file per worker, port per worker) can discover its worker identity.
- Tests that cannot safely run concurrently have an opt-out (`:serial`).

## Process-based, not thread-based

Threads in Raku are real (MoarVM has no GIL), but the runner uses processes, not
threads:

- Spec files declare top-level `class` / `role` / `enum` / `subset` / `constant`
  symbols. Loading two spec files into the same process can collide on those
  symbols. Loading them concurrently would turn collisions into races.
- User code commonly uses thread-hostile global state: DB connection objects,
  `%*ENV` mutation in `before-each`, `chdir`, signal handlers, framework
  singletons. Most of this is process-safe but not thread-safe.
- `EVAL` / `EVALFILE` and the surrounding compiler state are not designed to run
  multiple unrelated programs concurrently.
- `--bisect` and `--coverage` already shell out to subprocesses for isolation.
  Parallel execution follows the same pattern, so the operational model is
  uniform.

Each worker is a separate `raku bin/behave` subprocess.

## Worker lifecycle

```
parent (orchestrator)
  ├── discovery pass (load spec tree, plan buckets)
  ├── fork worker 0  ── runs assigned buckets, streams events back
  ├── fork worker 1  ── …
  ├── …
  ├── fork worker N-1
  ├── wait, aggregate
  └── serial phase (run any :serial examples on a single worker)
```

A worker:

1. Receives a manifest of the buckets it owns plus its `BEHAVE_WORKER_INDEX`
   and `BEHAVE_WORKER_COUNT`.
2. Loads every spec file it owns at least one bucket of (load cost is paid once
   per worker).
3. Walks the same `Runner` the serial path uses, with an additional filter that
   gates each example on "is this example in one of my assigned buckets?"
4. Emits one JSON line per spec-tree event on stdout. stderr is forwarded to the
   parent's stderr verbatim.
5. Exits `0` on a clean run regardless of test failures (failures are reported
   via events). A non-zero exit means the worker itself crashed: an uncaught
   exception escaping the runner, OOM, or a signal.

Workers are launched with `--worker-manifest <path>` (static distribution) or
`--queue-worker` (queue distribution). Both are hidden flags. Users never type
them.

## Spec discovery

Distribution requires the parent to know what groups exist so it can bucket
them. The parent runs a short-lived discovery subprocess
(`behave --no-config --list-examples --list-examples-format=json`), parses the
emitted JSON tree, and rebuilds a skeleton `Suite` / `ExampleGroup` / `Example`
tree used only for bucketing and event lookup. The parent never `EVALFILE`s a
user spec file, so user-declared `class` / `role` definitions never run in the
parent. Each bucket is keyed by `(file, group-path)`, where `group-path` is the
chain of `describe` / `context` descriptions from the suite root down to (but
not including) the leaf example.

In the pool modes (`lpt` / `queue`), affinity is enforced by bucketing on the
top-level `describe` / `context` (or a top-level `it`). Keeping a group's
examples on one worker lets `before-all` / `after-all` / `around-all` amortize
correctly instead of re-running per example.

## Work distribution

`--parallel-mode` selects the execution model:

- **`isolated` (default)**: one subprocess per spec file, with concurrency
  capped at `--parallel N` (or `$*KERNEL.cpu-cores`). A file's examples run
  together in their own process. There is no cross-file bucket packing and no
  persistent worker pool. Each running file leases a `BEHAVE_WORKER_INDEX` from
  a recycled pool of `0 .. N-1` slots (returned when the file finishes), so the
  index is bounded by the concurrency cap and concurrently-running files always
  hold distinct indices, letting user code key a per-worker resource (e.g. a
  per-worker database) off the index with only `N` resources to provision. This
  is the strongest isolation and the default.
- **`lpt`**: a fixed pool of `N` persistent workers. The parent sorts buckets
  by example count descending (a cost proxy in the absence of historical timing
  data), then greedily assigns each bucket to the worker with the smallest
  current load (longest-processing-time-first). This is a 4/3-approximation of
  optimal makespan. With `N` much smaller than the bucket count it lands within
  a few percent of perfect.
- **`queue`**: a fixed pool of `N` workers pulling buckets from a shared queue,
  so a worker that finishes early picks up the next available bucket. This wins
  when bucket costs are uneven and the bucket count comfortably exceeds the
  worker count. It costs a per-bucket coordination round-trip.

`isolated` is the default for maximal isolation. The `lpt` and `queue` pool
modes share the group-affinity bucketing above and trade some isolation for
fewer, longer-lived processes. `queue` further trades LPT's static balance for
dynamic rebalancing.

## `:serial` phase

Examples or groups tagged `:serial` are filtered out of the parallel manifests
during discovery. After all parallel workers exit cleanly, the parent forks one
more worker (index `0`, count `1`) with a manifest containing only the serial
examples and runs them sequentially.

`:serial` combines with existing filters using AND semantics, identical to
`:tag`:

- `--tag foo` + `:serial`: an example runs only if it has both `foo` and
  `:serial`.
- `--exclude-tag serial` skips them entirely.
- `--example PATTERN` and focus mode apply normally.

Failures in the serial phase merge into the same `RunResult` as the parallel
phase, and the summary stays a single line. If `--parallel` is omitted or is
`1`, `:serial` is a no-op: everything is already serial.

## IPC: parent ⇆ worker protocol

Workers emit one JSON line per event on stdout. Events cover the spec-tree
lifecycle (`suite-start`, `group-start`, `example-start`, `example-pass`,
`example-fail`, `example-pending`, `example-skipped`, `group-end`, `suite-end`,
`run-summary`), worker bookkeeping (`worker-ready`, `bucket-done`,
`load-error`), and the optional reporting streams (`profile-record`,
`benchmark-record`, `retry-record`) when their flags are
requested.

The parent reads these line by line, feeds them to the existing formatter
through a thin adapter, and aggregates counts into a single `RunResult`.

JSON-lines was chosen over a binary protocol or Raku-native serialization
because it is:

1. Trivially streamable: line-buffered, no length-prefix framing.
2. Debuggable: worker stdout can be dumped to a file and read directly.
3. Robust to stdout flushing edge cases: a half-line is detectable as malformed
   and reported, not silently lost.

stderr from workers is forwarded to the parent's stderr unchanged, so user
`note` / `say *.error` calls reach the user as-is.

## Output rendering

The parent owns the terminal. Workers never write directly to the user's stdout.

For the default `progress` formatter this is direct: the parent prints one
character per example event as it arrives: `.` for `example-pass`, `F` for
`example-fail`, `*` for `example-pending`, `S` for `example-skipped`.
Interleaved order across workers is fine. `progress` makes no per-line ordering
promise.

For the verbose and documentation formatters the parent buffers per suite: it
accumulates events for a `(worker, file)` pair until that worker emits
`suite-end` for the file, then flushes the whole suite to the formatter as one
block. This keeps a suite's nested output contiguous. The cost is bounded memory
per worker (one suite's worth of events). The formatter sees the same call
sequence it would in serial mode. The parent reorders the worker stream before
calling into it.

## Worker identity API

`BDD::Behave::Worker` exposes the current worker's identity:

```raku
class BDD::Behave::Worker {
  method id    (--> Int) { %*ENV<BEHAVE_WORKER_INDEX> // 0 }
  method count (--> Int) { %*ENV<BEHAVE_WORKER_COUNT> // 1 }
}
```

Both env vars are always set: in serial mode `BEHAVE_WORKER_INDEX=0` and
`BEHAVE_WORKER_COUNT=1`, so user config that interpolates
`BDD::Behave::Worker.id` into a DB name (`myapp_test_{id}`) behaves identically
in serial and parallel modes.

The values are seeded by the parent into each child's environment at fork time.
The accessors read the env vars on each call, so user mutation does not change
the reported identity.

## Seed mode

`--seed-mode` controls how `--seed N` combines with `--parallel K`:

- **`xor` (default)**: each worker gets a derived seed `seed XOR worker-index`.
  The summary still prints the root seed. Reproducible only when the worker
  count also matches.
- **`stable`**: every bucket gets a deterministic hash of
  `(file, group-path, seed)`. Buckets are sorted globally by that hash and the
  bucket at sorted position `i` is assigned to worker `i mod K`. The global
  hash-sorted order is identical regardless of `K`. Workers run
  `--order=defined` within their buckets. This reproduces a run across different
  worker counts.

## Interaction with existing flags

| Flag | Behavior under `--parallel N` |
| --- | --- |
| `--fail-fast` / `=N` | Forwarded to each worker, which stops at the threshold within its own slice. The parent does not aggregate counts across workers or terminate running workers. |
| `--order random` + `--seed` | See [Seed mode](#seed-mode). |
| `--order defined` | Within each worker, declared order is preserved for that worker's assigned buckets. |
| `--parallel-retry N` | When a worker crashes, the parent re-runs its buckets (up to `N` times) instead of failing the run. Applies to `--parallel-mode=lpt`. |
| `--bisect` / `--bisect-data` | Mutually exclusive with `--parallel`. The parent errors with a clear message. |
| `--coverage` | Compatible. The coverage subprocess wrapper runs outside the parallel layer. Each worker writes a per-worker coverage log path, and the parent merges them before reporting. |
| `--doc` | Ignores `--parallel` (doc mode does not execute, so parallelism is moot). |
| `--profile` / `--benchmark` | Records stream back via worker events. The parent merges them into the multi-file aggregation it already does. |
| `--only-example` / `--example` / `--tag` / `--exclude-tag` / focus | Filters are applied once during discovery and pushed into the worker manifest, so workers see exactly what they need to run. |
| `--aggregate-failures` | Pure per-example behavior, unchanged. |

## Known limitations

- **Discovery cost on huge suites.** A worker that owns buckets in every file
  pays that file's load cost, so a very large suite loads spec files more than
  once across the worker set.
- **No live progress totals.** The default `progress` formatter does not print
  "423 / 5000" mid-run. Parallel mode keeps that behavior.

## Non-goals

- Persistent workers across runs (would require detecting spec changes between
  runs).
- Distributed multi-host execution.
