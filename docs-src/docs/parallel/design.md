# Parallel Execution — Design Strategy

This document is the design strategy for roadmap item **9.1 Add parallel test execution**. It is the deliverable for **9.1.1** and the reference subsequent subtasks (9.1.2 – 9.1.8) implement against. It is *not* yet a user-facing guide — that lands with 9.1.3 and 9.1.8.

## Goal

Let `behave` run a spec suite across multiple workers concurrently, opt-in via `--parallel N`. Default (no flag) keeps the current single-process, single-worker behavior bit-for-bit.

Success criteria:

- A suite that takes T seconds serially takes roughly T / N seconds on N cores, modulo per-worker startup overhead and load imbalance.
- Failure output, summary counts, profile/memory/benchmark sections, exit code, and seed reporting remain meaningful and reproducible.
- User code that already assumes a fresh process per worker (DB connection per worker, file per worker, port per worker) has a clean way to discover its worker identity.
- Tests that *cannot* safely run concurrently with anything else have an opt-out (`:serial`).

## Constraints from the rest of 9.1

The roadmap text for 9.1.5 – 9.1.8 has already locked in several decisions, and this design has to satisfy them:

- **9.1.5** wants `BEHAVE_WORKER_INDEX` / `BEHAVE_WORKER_COUNT` env vars and a programmatic `BDD::Behave::Worker.id` / `.count`. Env vars are per-process — so workers are processes, not threads.
- **9.1.6** wants distribution at `ExampleGroup` granularity so `before-all` / `after-all` / `around-all` amortize correctly inside a single worker.
- **9.1.7** wants `:serial` to pin examples that mutate shared global state to a single worker, run after the parallel batch.
- **9.1.8** wants the canonical pattern to be DB-per-worker keyed off `BEHAVE_WORKER_INDEX`.

All four push toward process-based workers with strong isolation. None of them require shared memory between workers.

## Process-based, not thread-based

Threads in Raku are real (MoarVM has no GIL), but threading the runner would be the wrong call here:

- Spec files declare top-level `class`/`role`/`enum`/`subset`/`constant` symbols. Loading two spec files into the same process can already collide (see roadmap 9.7) — loading them concurrently into the same process would make the collision races as well as collisions.
- User code commonly uses thread-hostile global state — DB connection objects, `%*ENV` mutation in `before-each`, `chdir`, signal handlers, framework singletons. Most of this is process-safe but not thread-safe.
- `EVAL` / `EVALFILE` and the surrounding compiler state are not designed to run multiple unrelated programs concurrently.
- `--bisect` and `--coverage` already shell out to subprocesses for isolation. Parallel execution follows the same pattern, so the operational model is uniform.

So: each worker is a separate `raku bin/behave` subprocess.

## Worker lifecycle

```
parent (orchestrator)
  ├── discovery pass (load spec tree, plan shards)
  ├── fork worker 0  ── runs assigned groups, streams events back
  ├── fork worker 1  ── …
  ├── …
  ├── fork worker N-1
  ├── wait, aggregate
  └── serial phase (run any :serial examples on a single worker)
```

A worker:

1. Receives, on stdin or via a temp control file, a manifest of `(spec-file, group-path)` shards plus its `BEHAVE_WORKER_INDEX` and `BEHAVE_WORKER_COUNT`.
2. `EVALFILE`s every spec file it owns at least one shard of (load cost is paid once per worker).
3. Walks the same `Runner` we already have, but with an additional filter that gates each example on "is this example in one of my assigned shards?"
4. Emits one JSON line per spec-tree event (suite-start, example-start, example-pass, example-fail, example-skip, suite-end) on stdout. stderr is forwarded to the parent's stderr verbatim.
5. Exits 0 on a clean run (regardless of test failures — failures are reported via events). Non-zero exit is reserved for *worker crashes* (uncaught exception escaping the runner, OOM, signal).

The worker is launched as `raku -Ilib bin/behave --worker-mode <manifest-path>` so the same binary serves both roles. `--worker-mode` is a hidden flag; users never type it.

## Spec discovery

Group affinity (9.1.6) requires the parent to know what groups exist so it can shard them. Two options were considered:

1. **Parent loads the tree itself.** The parent `EVALFILE`s every spec into its own registry, then partitions. Cheapest, but inherits the 9.7 in-process collision problem and pays the load cost twice (parent + each worker that owns any group from that file).
2. **Discovery subprocess.** The parent forks a single short-lived `behave --list-examples --format json` (9.6.2) subprocess that dumps the example metadata, then partitions from the JSON.

**Decision: option 2**, gated on 9.6.2. If 9.6.2 is not yet implemented when 9.1.2 lands, we ship 9.1 with option 1 as a stopgap and migrate to option 2 after 9.6.2 lands. The migration is a one-function swap inside the parent — workers don't care how the manifest was computed.

The discovery output is normalized to a list of records:

```
{ file: "specs/foo-spec.raku", group-path: ["FooThing", "when X"], example-count: 7, file-line: 42, tags: [...], serial: false }
```

`group-path` is the chain of `describe`/`context` descriptions from the suite root down to (but not including) the leaf example. Affinity is enforced by sharding on the *deepest* group that fits a single worker comfortably — by default the top-level `describe`. Users with one very large top-level `describe` can opt into a finer split with metadata (see "Future work" below).

## Work distribution

**Static partitioning, longest-processing-time-first (LPT).** The parent sorts discovered groups by `example-count` descending (a rough cost proxy in the absence of historical timing data), then greedily assigns each group to the worker with the smallest current load. This is a 4/3-approximation of optimal makespan; in practice, with N << group-count, it's within a couple percent of perfect.

We deliberately do *not* start with a dynamic work-stealing queue:

- It requires a control channel and protocol that workers can pull from; that's a lot of complexity for a v1.
- With group affinity, work units are already coarse (a `describe` block), so the gain from stealing is small in the common case.
- A future PR can add `--parallel-mode=queue` if real-world suites show LPT is leaving too much idle worker time.

Future timing data (from `--profile` history or `.behave-timings.json`) can replace `example-count` as the cost proxy without changing the algorithm. That's an enhancement, not a v1 requirement.

## `:serial` phase

Examples or groups tagged `:serial` are filtered out of the parallel manifests during discovery. After all parallel workers have exited cleanly, the parent forks one more worker (worker index 0, count 1) with a manifest containing only the serial examples and runs them sequentially.

`:serial` interacts with existing flags using AND semantics, identical to `:tag`:

- `--tag foo` + `:serial`: example runs only if it has both `foo` and `:serial`.
- `--exclude-tag serial` skips them entirely.
- `--example PATTERN` and focus mode apply normally.

Failures in the serial phase merge into the same `RunResult` as the parallel phase. The summary line stays a single line.

If `--parallel` is omitted or is 1, `:serial` is a no-op — everything is already serial.

## IPC: parent ⇆ worker protocol

Workers emit one JSON line per event on stdout. Events:

- `{type: "suite-start", file, group-path, started-at}`
- `{type: "example-start", file, line, description, full-description}`
- `{type: "example-pass", file, line, duration-ms}`
- `{type: "example-fail", file, line, duration-ms, failures: [...]}`
- `{type: "example-skip", file, line, reason}`
- `{type: "example-pending", file, line, reason}`
- `{type: "suite-end", file, group-path, counts: {...}}`
- `{type: "profile-record", file, line, duration-ms}` (only when `--profile` requested)
- `{type: "memory-record", ...}` (only when `--memory-profile` requested)
- `{type: "benchmark-record", ...}` (only when `--benchmark` requested)
- `{type: "worker-error", message, backtrace}` for worker-internal failures (uncaught exception in the runner itself, not in user code)

The parent reads these line-by-line (a `Tap` on the worker's stdout `Channel`), feeds them to the existing formatter via a thin adapter, and aggregates counts into a single `RunResult`.

Format choice — JSON-lines — was picked over a binary protocol or a Raku-native serialization for three reasons:

1. Trivially streamable, line-buffered, no length-prefix framing.
2. Debuggable: `BEHAVE_WORKER_DEBUG=1` can dump worker stdout to a file and you can read it.
3. Survives stdout flushing edge cases (a half-line is detectable as malformed and reported, not silently lost).

stderr from workers is forwarded to the parent's stderr unchanged. User `note` / `say *.error` calls reach the user as-is.

## Output rendering

The parent owns the terminal. Workers never write directly to the user's stdout.

For the default `progress` formatter, this is trivial: the parent prints one `.` / `F` / `*` per `example-pass` / `example-fail` / `example-skip` event as it arrives, in the order events arrive. Interleaved order across workers is fine — `progress` already makes no per-line ordering promise.

For the verbose / documentation formatters, the parent buffers per-suite: it accumulates events for a given `(worker, file)` pair until that worker emits `suite-end` for the file, then flushes the whole suite as a single block to the formatter. This keeps a single suite's nested output contiguous on the terminal. The cost is bounded memory per worker (one suite's worth of events).

This is 9.1.4 ("Handle parallel output"). It does *not* require formatter changes — the formatter sees the same call sequence it would in serial mode; the parent just reorders the worker stream before calling into it.

## Worker identity API

`BDD::Behave::Worker` is a new tiny module:

```raku
class BDD::Behave::Worker {
  method id    (--> Int) { %*ENV<BEHAVE_WORKER_INDEX> // 0 }
  method count (--> Int) { %*ENV<BEHAVE_WORKER_COUNT> // 1 }
}
```

Both env vars are always set: in serial mode `BEHAVE_WORKER_INDEX=0` and `BEHAVE_WORKER_COUNT=1`, so user config that interpolates `BDD::Behave::Worker.id` into a DB name (`myapp_test_{id}`) works identically in serial and parallel modes. This is the explicit requirement from 9.1.5.

The accessor is read-only at the user level; the values are seeded by the parent in the child's environment at fork time and must not be mutated by user code (mutation would be a no-op anyway since the env vars are read each call — but mutation in `before-each` would cause confusing readings, so docs will note it).

## Interaction with existing flags

| Flag                         | Behavior under `--parallel N`                                                                 |
| ---------------------------- | --------------------------------------------------------------------------------------------- |
| `--fail-fast` / `=N`         | Parent tracks aggregated failure count; sends SIGTERM to workers when threshold hit.          |
| `--order random` + `--seed`  | Each worker gets a *derived* seed `seed XOR worker-index`. Summary still prints the root seed. |
| `--order defined`            | Within each worker, declared order is preserved for that worker's assigned groups.            |
| `--bisect` / `--bisect-data` | Mutually exclusive with `--parallel`. The parent errors with a clear message.                 |
| `--coverage`                 | Compatible. The parent's coverage subprocess wrapper runs *outside* the parallel layer; each worker writes to a per-worker coverage log path, and the parent merges them before reporting. (Detail belongs to 9.1.8.) |
| `--doc`                      | Ignores `--parallel` — doc mode does not execute, so parallelism is moot.                     |
| `--profile` / `--memory-profile` / `--benchmark` | Records are streamed back via worker events; parent merges into the multi-file aggregation it already does. |
| `--only-example` / `--example` / `--tag` / `--exclude-tag` / focus | Filters are pushed into the worker manifest, not re-applied in workers. The parent does one filter pass during discovery so workers see exactly what they need to run. |
| `--aggregate-failures`       | Pure per-example behavior, unchanged.                                                          |

## Known limitations (v1)

- **Determinism across worker counts.** A given `--seed` reproduces the run only when the worker count also matches. A separate flag (`--seed-mode=stable`) could fix this later by mapping examples to workers via a stable hash; not v1.
- **Discovery cost on huge suites.** A 10,000-example suite discovered via option 2 (subprocess) pays the load cost twice on a worker that owns groups in every file. Real timing data will tell us whether the optimization is worth a worker-side discovery cache; not v1.
- **No live progress totals.** The default `progress` formatter does not print "423 / 5000" mid-run. Parallel mode keeps the same behavior. A future formatter event can add this.
- **Worker crashes are fatal.** If a worker exits non-zero from an uncaught runner exception, the parent prints the partial transcript and exits 1. We do not currently retry the assigned shard on another worker. Adding retry is a 9.3 concern.

## Implementation phasing

This maps the design back onto the open roadmap subtasks:

- **9.1.2 Worker pool.** Implement `BDD::Behave::Parallel::WorkerPool` (process spawn, manifest serialization, event reader, lifecycle/cleanup). Unit-test against a fake worker binary.
- **9.1.3 `--parallel N` flag.** Wire it into `bin/behave` and config. Add LPT distribution. End-to-end specs against a small spec dir.
- **9.1.4 Output coordination.** Add the per-worker buffering adapter that feeds the existing formatter.
- **9.1.5 Worker identity.** `BDD::Behave::Worker` module + env-var plumbing in `WorkerPool` + parity in serial mode.
- **9.1.6 Group affinity.** Already baked into the distribution; this subtask is the spec proving it (`before-all` runs once per worker per group, not once per example) plus opt-in metadata for splitting large groups.
- **9.1.7 `:serial` metadata.** Discovery splits the manifest into parallel + serial buckets; parent runs the serial phase after the parallel phase.
- **9.1.8 DB-per-worker guide.** User-facing `docs-src/docs/parallel/parallel.md` covering the canonical fixture/cleanup pattern plus mkdocs nav entry.

Open items intentionally deferred outside 9.1:

- Work stealing / dynamic queue (revisit if static LPT proves inadequate).
- Worker pooling across runs / persistent workers (would require detecting spec changes; out of scope).
- Distributed multi-host execution (not on the roadmap).

## What this document is not

This is the strategy, not the API contract. Module names (`BDD::Behave::Parallel::WorkerPool`, `BDD::Behave::Worker`) and event field names are *proposed*; the implementing PR can refine them. If a name or shape changes during 9.1.2 – 9.1.8, this doc is updated to match.
