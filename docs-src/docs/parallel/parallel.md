# Parallel Execution

`behave --parallel N` runs your spec suite across `N` worker subprocesses concurrently. Default (no flag) keeps single-process serial execution, bit-for-bit identical to prior releases.

```shell
$ behave --parallel 4
```

## How it works

Behave's parent process discovers your spec tree, splits it into work shards, then forks `N` `raku bin/behave --worker-manifest …` subprocesses. Each worker loads only the spec files it owns shards in, runs only its assigned examples, and streams structured JSON events back to the parent over stdout. The parent renders those events into your chosen formatter so your terminal sees a single coherent run, not `N` interleaved transcripts.

Workers are subprocesses, not threads — every worker has its own Raku runtime, its own loaded classes, and its own `%*ENV`. State you mutate in one example never leaks to another worker.

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

| Variable                 | Meaning                                     |
| ------------------------ | ------------------------------------------- |
| `BEHAVE_WORKER_INDEX`    | This worker's zero-based index (0..count-1) |
| `BEHAVE_WORKER_COUNT`    | The total worker count for this run         |

Both are always set: in single-process mode `BEHAVE_WORKER_INDEX=0` and `BEHAVE_WORKER_COUNT=1`, so configuration that interpolates the index into a per-worker resource name works identically in serial and parallel modes.

```raku
# Pick a DB by worker index — works in serial (index=0, count=1) and parallel modes.
use BDD::Behave::Worker;

my $db-name = "myapp_test_{BDD::Behave::Worker.id}";
```

## Seed mode (`--seed-mode`)

`--seed-mode` controls how `--seed N` combines with `--parallel K`:

| Mode      | Bucket → worker assignment                | Within-worker shuffle seed         | K-invariant? |
| --------- | ----------------------------------------- | ---------------------------------- | ------------ |
| `xor` (default) | Longest-processing-time-first (LPT) | `parent-seed XOR worker-index`     | No: changing `K` reshuffles assignment and per-worker seeds. |
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

| Flag                   | Behavior under `--parallel N`                                                          |
| ---------------------- | -------------------------------------------------------------------------------------- |
| `--bisect` / `--bisect-data` | Mutually exclusive with `--parallel`. The parent errors with a clear message.    |
| `--coverage`           | Not yet supported with `--parallel` in this release; the parent errors.                 |
| `--doc`                | Ignores `--parallel` — doc mode does not execute, so parallelism is moot.               |
| `--tag` / `--exclude-tag` / `--example` / `--only-example` | Applied during discovery; each worker sees exactly its filtered slice. |
| `--seed`               | See `--seed-mode` below — `xor` (default) derives a per-worker seed (`seed XOR worker-index`); `stable` keeps the seed identical across workers and uses hash-based bucket assignment. The root seed is printed at end of run either way. |
| `--seed-mode`          | `xor` (default) or `stable`. `stable` makes the global execution order K-invariant for a given `--seed`. See [Seed mode](#seed-mode-seed-mode). |
| `--fail-fast`          | Aggregated across workers. Surviving workers are SIGTERMed at threshold (best-effort). |

## Known limitations (v1)

- **Reproducibility across worker counts.** Default (`--seed-mode=xor`) reproduces only when `--parallel N` matches. Use `--seed-mode=stable` for a K-invariant execution order.
- **No live progress totals.** The `progress` formatter still emits one character per example as events arrive, but there's no "423 / 5000" running total.
- **Profile / memory / benchmark sections.** `--profile`, `--memory-profile`, and `--benchmark` are not yet aggregated across workers in parallel mode. Run a serial pass for those.
- **`--coverage` integration.** Pending; combine `--parallel` with `--coverage` and Behave will error out for now.
- **Worker crashes are fatal.** If a worker exits with code > 1 (signal, uncaught exception in the runner itself), the parent prints the partial transcript and exits 1. There is no per-shard retry — that's a 9.3 concern, not parallel-execution scope.

## See also

- [Tags](../tags/tags.md) — the `:tag` / `:exclude-tag` machinery underpinning `:serial` and `:database` patterns.
- [Hooks](../hooks/hooks.md) — `before-each` / `after-each` filters for transaction wrapping.
- [Configuration](../configuration/configuration.md) — adding a `--parallel` default to a project `.behave` file.
