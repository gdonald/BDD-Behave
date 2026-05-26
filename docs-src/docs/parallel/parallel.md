# Parallel Execution

`behave` runs every spec file in its own subprocess by default, up to a concurrency cap of `$*KERNEL.cpu-cores`. Pass `--parallel N` to set a different concurrency cap.

```shell
$ behave             # one subprocess per spec file, up to CPU-cores in flight
$ behave --parallel 4 # one subprocess per spec file, up to 4 in flight
```

## How it works

Behave's parent process discovers your spec tree, then for each spec file spawns a fresh `raku bin/behave --worker-manifest …` subprocess. Each worker loads exactly one spec file, runs its assigned examples, and streams structured JSON events back to the parent over stdout. A semaphore caps the number of concurrent subprocesses. The parent renders the events into your chosen formatter so your terminal sees a single coherent run, not `N` interleaved transcripts.

Workers are subprocesses, not threads — every worker has its own Raku runtime, its own loaded classes, and its own `%*ENV`. State you mutate in one example never leaks to another worker.

## The file boundary is the isolation boundary

Because each spec file loads in its own subprocess, **cross-file in-process state cannot be shared via spec files**. If file A declares a `define-matcher`, `shared-examples`, or `shared-contexts` block and file B references it by name, the reference will fail under the default loader — file B's subprocess never loaded file A.

Put anything that needs to be available to multiple spec files in a module under `lib/` and `use` it from each spec:

```raku
# lib/MyProject/SharedMatchers.rakumod
unit module MyProject::SharedMatchers;

use BDD::Behave;

define-matcher 'be-a-positive-integer', {
  match -> $actual { $actual ~~ Int && $actual > 0 }
}
```

```raku
# specs/whatever-spec.raku
use BDD::Behave;
use MyProject::SharedMatchers;

describe 'order quantity', {
  it 'is a positive integer', {
    expect(42).to.be-a-positive-integer;
  }
}
```

This is the same pattern that has always worked across `--parallel` workers — making file-as-isolation-boundary the default just makes it universal.

## Why subprocess-per-file

Loading multiple spec files into one process has hazards that don't exist when each file lives in its own subprocess. The most common is a runtime `require ::($name)` inside one spec (for example `DBIish.connect(...)` lazy-loading a driver) mutating the host process's GLOBAL in a way that breaks subsequent `X::*`-prefixed symbol lookups in other specs that already imported them. Per-file subprocesses sidestep this class of problem entirely.

### Discovery subprocess

Spec discovery itself also runs in a subprocess. Before launching workers, the parent invokes `raku bin/behave --no-config --list-examples --list-examples-format=json <spec-files>`, parses the emitted JSON tree, and rebuilds a skeleton `Suite` / `ExampleGroup` / `Example` tree used only for bucket distribution and event lookups. The parent itself never `EVALFILE`s any user spec file, so user-declared `class` / `role` definitions and other top-level effects never run in the parent and cannot collide with one another or with Behave's own loaded modules.

## Group affinity

All examples inside a `describe` / `context` block run on the same worker. This makes `before-all`, `after-all`, and `around-all` amortize correctly — one setup per group per worker, not `N` setups per group. Distribution happens at the top-level `describe` granularity by default.

If a group is unusually large and would benefit from being split across workers, opt in with `:parallel-split`:

```raku
describe 'huge group with 5000 cases', :parallel-split, {
  it ...
  it ...
  # …
}
```

`:parallel-split` lets the distributor consider each child of the group as an independent unit. Inner `before-all` / `after-all` will run once *per worker* that gets any of the children, so split only when the speedup is worth the duplicated setup.

## Worker identity

Inside spec code, `BDD::Behave::Worker.id` and `BDD::Behave::Worker.count` give the current worker's zero-based index and the total worker count. Both are also exposed as environment variables:

| Variable              | Meaning                                     |
| --------------------- | ------------------------------------------- |
| `BEHAVE_WORKER_INDEX` | This worker's zero-based index (0..count-1) |
| `BEHAVE_WORKER_COUNT` | The total worker count for this run         |

Both are always set — each spec file's subprocess sees its index and the total concurrency cap. Configuration that interpolates the index into a per-worker resource name works in any concurrency configuration.

```raku
# Pick a DB by worker index.
use BDD::Behave::Worker;

my $db-name = "myapp_test_{BDD::Behave::Worker.id}";
```

## Seed mode (`--seed-mode`)

`--seed-mode` controls how `--seed N` combines with `--parallel K`:

| Mode            | Bucket → worker assignment          | Within-worker shuffle seed                                         | K-invariant?                                                             |
| --------------- | ----------------------------------- | ------------------------------------------------------------------ | ------------------------------------------------------------------------ |
| `xor` (default) | Longest-processing-time-first (LPT) | `parent-seed XOR worker-index`                                     | No: changing `K` reshuffles assignment and per-worker seeds.             |
| `stable`        | Deterministic hash mod `K`          | Parent seed (same for every worker); workers run `--order=defined` | Yes: the global hash-sorted bucket order is identical regardless of `K`. |

### `stable`

```shell
$ behave --parallel 4 --seed 12345 --seed-mode stable
```

In `stable` mode, every bucket (top-level `describe` / `context`, or top-level `it`) gets a deterministic 32-bit hash derived from its file path, group-path / line, and the run seed. Buckets are sorted globally by that hash, then assigned to `K` workers round-robin: bucket at sorted-position `i` goes to worker `i mod K`. Within each worker, buckets execute in sorted order; within a bucket, examples execute in declared order.

The result: rerunning the same suite with the same seed but different `K` always processes examples in the same global hash-sorted order — only the partition across workers changes. Use this when you need reproducibility across machines whose available parallelism differs.

Caveats:

- Stable mode forces `--order=defined` per worker (the global hash-sort handles ordering).
- LPT load-balancing is replaced by hash-mod-`K`, so workers can be slightly less balanced than `xor` mode on suites with uneven groups.
- Auto-generated seeds (when you omit `--seed`) are still printed at the end of the run, so `behave --parallel 3 --seed-mode stable` is reproducible by copying the printed seed back into the next run.

### `xor` (default)

`xor` mode is the default for unsurprising single-machine behavior: the LPT distributor balances by `example-count`, and each worker shuffles its slice using `parent-seed XOR worker-index`. Two runs with the same `--seed N --parallel K` are reproducible only when `K` matches.

## Parallel mode (`--parallel-mode`)

`--parallel-mode` controls *how* buckets are mapped to workers under `--parallel K`. The default is the static LPT distributor described above; the alternative is a dynamic queue.

| Mode            | Strategy                                                         | When to use                                                                       |
| --------------- | ---------------------------------------------------------------- | --------------------------------------------------------------------------------- |
| `lpt` (default) | Static longest-processing-time-first, cost proxy = example count | Most suites where example count is a reasonable cost proxy.                       |
| `queue`         | Dynamic work-stealing: workers pull buckets one at a time        | Suites with wildly uneven runtimes where example count poorly predicts wall time. |

### `queue`

```shell
$ behave --parallel 4 --parallel-mode queue
```

In `queue` mode the parent maintains a FIFO queue of buckets sorted by cost (example count) descending, and dispatches one bucket to each worker over its stdin pipe. As each worker finishes its bucket it pulls the next one. When the queue is empty the parent sends `SHUTDOWN` to every worker and waits for them to exit.

Worker behavior in queue mode:

- Spec files are loaded **lazily** on the first bucket from that file (vs. eagerly at startup in LPT mode). If a worker never receives a bucket from a file, it never loads that file.
- Each worker forces `--order=defined` for the examples inside its current bucket. Dispatch order between buckets is cost-desc, then arrival order; within a bucket, declared order.
- `:serial` examples are still routed to a single post-parallel serial worker, exactly as in LPT mode.

### When queue mode helps

Queue mode wins over LPT when:

- A few buckets dominate runtime but have similar example counts to the rest (so LPT's example-count proxy can't tell them apart).
- The bucket count significantly exceeds the worker count, giving the queue many opportunities to rebalance.
- Per-example runtime varies by an order of magnitude across the suite.

Queue mode tends to match LPT (and adds a small per-bucket coordination overhead) when:

- The suite has fewer buckets than workers — neither strategy can prevent idle workers.
- Example counts are well-correlated with runtime.
- One single bucket dominates total runtime — both strategies bottleneck on it.

The roadmap notes that "default stays static LPT": queue mode is opt-in. Benchmark your own suite with both modes before flipping the default.

### Reproducibility

Queue mode is **inherently non-deterministic** in bucket-to-worker assignment: which worker ends up running a given bucket depends on real wall-clock timing. Pass-fail outcomes are deterministic (each example runs exactly once), but the worker number reported for an example, the per-worker bucket order, and per-worker timing will vary run-to-run. `--seed` still seeds within-example randomness, but bucket dispatch order is timing-driven.

If you need cross-run reproducibility under `--parallel`, use `--seed-mode stable` with the default `--parallel-mode lpt`.

## Per-shard retry on worker crash (`--parallel-retry`)

A worker subprocess can die for reasons unrelated to a test failure: a SIGKILL from the OOM killer, a segfault, an uncaught exception in the runner itself, or a runaway example calling `exit`. By default the parent prints whatever transcript it had and exits 1.

`--parallel-retry N` adds per-shard retry: when a worker exits with code > 1 (test failures use exit 1 and do **not** trigger this path), the parent re-spawns it with the same manifest up to `N` additional times. Buffered events from the crashed attempt are discarded so the user-visible transcript reflects only the final attempt:

```shell
$ behave --parallel 4 --parallel-retry 2
```

A typical end-of-run summary shows the retried shards:

```
Shard retries: 1
  worker 2: recovered after 2 attempts (crash exit codes: 137; final exit: 0)
```

If every attempt crashes the run still exits 1, with the shard listed as `crashed`:

```
Shard retries: 1
  worker 2: crashed after 3 attempts (crash exit codes: 137, 137, 137; final exit: 137)
```

`--parallel-retry` composes with `--retry N` (per-example flake retry, [9.3]): a flaky example retries inside one worker incarnation; a crashed worker spawns a fresh incarnation that re-runs its whole manifest. Both counts are independent.

Caveats:

- Under `--parallel-retry N`, the parent **buffers** per-worker events until the worker exits. The transcript no longer streams in real time during the worker's run; instead each worker's events appear as a batch once the worker terminates. This is the price of being able to discard a crashed attempt cleanly. With `--parallel-retry 0` (the default) the streaming behavior is preserved.
- `--parallel-retry` only applies under `--parallel-mode=lpt` (the default). Queue mode dispatches buckets dynamically, so "re-spawn with the same manifest" has no analogue; a queue-mode worker crash remains fatal.

## Live progress totals (`--progress-total`)

By default the `progress` formatter streams one character per example (`.` / `F` / `*` / `S`) with no running count. Pass `--progress-total` to append a `(N/TOTAL)` counter after each char, where `TOTAL` is the example count discovered by the parent after applying tag / `--example` / location filters:

```shell
$ behave --parallel 4 --progress-total
. (1/247)
. (2/247)
F (3/247)
…
. (247/247)
```

Each event prints on its own line so the output is grep-friendly and works in non-TTY contexts (CI logs, captured stdout). Without `--parallel`, `--progress-total` is a no-op — totals are computed by the parallel parent at discovery time.

## Database-per-worker pattern

This is the canonical pattern for testing against a real database under `--parallel`:

1. **Provision N databases up front, one per worker.** Outside the test run — typically in your CI setup or a `.behave-setup` script.
2. **Each worker uses `BDD::Behave::Worker.id`** (or `BEHAVE_WORKER_INDEX`) to pick *its* database. The worker process boots once; its DB handle is created against `myapp_test_${BEHAVE_WORKER_INDEX}` and lives for the whole worker.
3. **Wrap each example in a transaction** (or use the truncation strategy if you can't use transactions because the code under test commits). Roll back at `after-each` so the next example in the same worker sees a clean slate.
4. **Tag DB-touching examples with `:database`** and define a `before-each :tag<database>` that opens the transaction.
5. **Use `:no-transaction`** (or your own tag) for examples that genuinely need to verify committed state.

```raku
# .behave config
use BDD::Behave;
use BDD::Behave::Worker;

before-each :tag<database>, {
  my $db = $*DB;
  $db.execute('BEGIN');
}

after-each :tag<database>, {
  my $db = $*DB;
  $db.execute('ROLLBACK') unless $*BEHAVE-NO-TRANSACTION;
}
```

```raku
# specs/user-spec.raku
describe 'User CRUD', :tag<database>, {
  it 'inserts a user', {
    User.create(name => 'gd').save;
    expect(User.all.elems).to.be(1);   # transaction rolls back after the example
  }
}
```

## `:serial` for non-parallelizable examples

Mark examples or groups that mutate global state — `%*ENV`, signal handlers, a shared external resource, a process-wide singleton — with `:serial`:

```raku
describe 'global config mutation', :serial, {
  it 'flips a process-wide flag', { ... }
}

it 'tests the parallel runner itself', :serial, { ... }
```

`:serial` examples are filtered out of the parallel batch and run sequentially on a single worker after every parallel worker has exited. They combine with `--tag` / `--exclude-tag` / `--example` filters using the usual AND semantics.

`:serial` is a no-op when `--parallel` is absent (everything is already serial).

## Interaction with other flags

| Flag                                                       | Behavior under `--parallel N`                                                                                                                                                                                                             |
| ---------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `--bisect` / `--bisect-data`                               | Mutually exclusive with `--parallel`. The parent errors with a clear message.                                                                                                                                                             |
| `--coverage`                                               | Each worker writes its own raw MoarVM coverage log; the parent merges the logs and renders a single coverage report. `--coverage-minimum` is gated on the merged percentage. See [below](#coverage).                                      |
| `--doc`                                                    | Ignores `--parallel` — doc mode does not execute, so parallelism is moot.                                                                                                                                                                 |
| `--tag` / `--exclude-tag` / `--example` / `--only-example` | Applied during discovery; each worker sees exactly its filtered slice.                                                                                                                                                                    |
| `--seed`                                                   | See `--seed-mode` below — `xor` (default) derives a per-worker seed (`seed XOR worker-index`); `stable` keeps the seed identical across workers and uses hash-based bucket assignment. The root seed is printed at end of run either way. |
| `--seed-mode`                                              | `xor` (default) or `stable`. `stable` makes the global execution order K-invariant for a given `--seed`. See [Seed mode](#seed-mode-seed-mode).                                                                                           |
| `--fail-fast`                                              | Aggregated across workers. Surviving workers are SIGTERMed at threshold (best-effort).                                                                                                                                                    |

## Default-on parallel from `.behave`

`--parallel N` can be set as a project (or user) default through the [config file](../configuration/configuration.md):

```raku
# .behave
use BDD::Behave::Configuration;

configure-behave -> $c {
  $c.parallel = 4;
  $c.parallel-mode = 'queue';
}
```

After this, `behave` alone runs the suite under 4 workers. The usual precedence applies: CLI > project (`./.behave`) > user (`~/.behave`) > built-in default (serial). A CLI `--parallel N` overrides the config value; pass `--parallel 1` to opt back into single-worker parallel execution from a higher-N config setting, or use `--no-config` to bypass the config entirely for one run.

## Known limitations (v1)

- **Reproducibility across worker counts.** Default (`--seed-mode=xor`) reproduces only when `--parallel N` matches. Use `--seed-mode=stable` for a K-invariant execution order.
- ~~**No live progress totals.**~~ Use `--progress-total` (see above) to print `(N/TOTAL)` after each example char.
- ~~**Profile / memory / benchmark sections.**~~ `--profile`, `--memory-profile`, and `--benchmark` are now aggregated across workers (see [below](#profile-memory-benchmark)).
- ~~**`--coverage` integration.**~~ `--coverage` is now aggregated across workers (see [below](#coverage)).
- ~~**Worker crashes are fatal.**~~ Use `--parallel-retry N` (see above) to re-spawn crashed shards. Default behavior with `--parallel-retry 0` keeps the previous fatal semantics. Queue mode still treats a crashed worker as fatal.

## Profile, memory, benchmark {#profile-memory-benchmark}

`--profile`, `--memory-profile`, and `--benchmark` work under `--parallel`. Each worker measures its own slice; the parent collects every record over the JSON-event stream and renders a single combined section at the end of the run, the same as serial mode.

```bash
behave --parallel 4 --profile=10 specs/
behave --parallel 4 --memory-profile=10 specs/
behave --parallel 4 --benchmark specs/
```

`--benchmark-baseline` and `--benchmark-save` apply to the aggregated measurements:

```bash
# Save a baseline computed from a 4-worker parallel run
behave --parallel 4 --benchmark-save=bench.tsv specs/

# Compare a later parallel run against it
behave --parallel 4 --benchmark --benchmark-baseline=bench.tsv specs/
```

Notes:

- Each example runs on exactly one worker, so `--profile` and `--memory-profile` rows are not deduplicated — the parent sees one record per execution.
- `--benchmark-iterations=N` and `--benchmark-threshold=PCT` are forwarded to every worker; per-example timings collected across iterations are merged in the parent before medians are computed.
- `--benchmark-baseline` / `--benchmark-save` are not forwarded to workers; only the parent reads / writes baseline files, against the aggregated summary list.

## Coverage {#coverage}

`--coverage` works under `--parallel`. The parent assigns each worker its own `MVM_COVERAGE_LOG` path (`$TMPDIR/behave-coverage-parallel-<pid>-<stamp>/worker-N.raw`), the workers run their slice of the spec tree under MoarVM coverage tracking, and the parent merges every per-worker log into a single hit map before rendering the report. The merge is a set union — coverage records whether a line was hit, not how many times — so a line counted only by worker 2 still shows up in the merged report.

```bash
behave --parallel 4 --coverage specs/
behave --parallel 4 --coverage --coverage-format=html --coverage-output=coverage specs/
behave --parallel 4 --coverage --coverage-minimum=90 specs/
```

`--coverage-include` / `--coverage-exclude` apply during the merge — same semantics as serial coverage. `--coverage-minimum` is gated on the *merged* percentage, so a line hit by any single worker contributes. `--coverage-baseline` compares the merged report against the saved baseline, the same as serial mode.

Notes:

- The parent process never has `MVM_COVERAGE_LOG` set, so it does not record its own bytecode. Coverage only reflects user code executed inside workers.
- `:serial` examples run on the post-parallel serial worker, which also writes to a per-worker log (`serial.raw`); its hits merge in with everyone else's.
- Worker raw logs can be very large (hundreds of megabytes per worker on big suites). The merge uses `grep -ahF | awk '!seen'` over the worker logs, so peak transient disk in `$TMPDIR` is proportional to the *raw* per-worker volume, not the filtered set. Workers' raw logs are deleted as soon as the merged-and-deduped file is written.

## See also

- [Tags](../tags/tags.md) — the `:tag` / `:exclude-tag` machinery underpinning `:serial` and `:database` patterns.
- [Hooks](../hooks/hooks.md) — `before-each` / `after-each` filters for transaction wrapping.
- [Configuration](../configuration/configuration.md) — adding a `--parallel` default to a project `.behave` file.
- [Coverage](../coverage/coverage.md) — full coverage reference (formats, baseline, branch tracking).
