# Running Specs

The `behave` command runs Behave specs.

## Default behavior

With no arguments, `behave` looks for a `specs/` directory under the current working directory and runs every file matching `spec.raku` (recursively).

```shell
$ behave
```

## Selecting files

Pass one or more spec file paths to run a subset:

```shell
$ behave specs/users-spec.raku specs/admin-spec.raku
```

## Local development

When you're working on Behave itself (or your project's `lib/` is not yet installed), tell Raku where to find the modules:

```shell
$ raku -Ilib bin/behave
$ raku -Ilib bin/behave specs/some-spec.raku
```

## Options

| Option               | Effect                                                                                                                  |
| -------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| `--help`             | Display usage                                                                                                           |
| `--verbose`          | Print each spec file as it is loaded                                                                                    |
| `--tag NAME`         | Run only examples tagged `NAME` (repeatable; OR semantics). See [Tags](tags/tags.md).                                    |
| `--exclude-tag NAME` | Skip examples tagged `NAME` (repeatable).                                                                               |
| `--example PATTERN`  | Run only examples whose full nested description matches `PATTERN` (substring; or `/regex/`). Repeatable; OR semantics.  |
| `-e PATTERN`         | Alias for `--example`.                                                                                                  |
| `--aggregate-failures` / `--aggregate-failures=LABEL` | Wrap every example in `aggregate-failures` semantics; converts uncaught example exceptions into recorded failures. With `=LABEL` the label tags each failure. Per-example/group `:aggregate-failures` metadata overrides this. See [Aggregate failures](expectations/aggregate-failures.md#automatic-aggregation). |
| `--order ORDER`      | Example execution order: `random` (default) or `defined`. Random order shuffles the children of every group and the suite, surfacing hidden order dependencies. See [Order and seed](#order-and-seed). |
| `--seed N`           | Seed the random-order RNG for reproducible runs. Ignored when `--order=defined`. Auto-generated when omitted and `--order=random`. See [Order and seed](#order-and-seed). |
| `--fail-fast`        | Stop after the first failed example. Equivalent to `--fail-fast=1`. See [Fail-fast](#fail-fast). |
| `--fail-fast=N`      | Stop after `N` failed examples (`N` must be a positive integer). See [Fail-fast](#fail-fast). |
| `--only-example LOC` | Run only examples whose `file:line` matches `LOC` (repeatable; OR semantics). `LOC` is `FILE:LINE` — `FILE` may be absolute, relative, or a basename. See [Bisect](#bisect). |
| `--bisect`           | Find the minimal set of examples that, run in declared order before each failing example, reproduce the failure. See [Bisect](#bisect). |
| `--bisect-data`      | Machine-readable output for use by `--bisect`. Suppresses normal output and emits `behave-executed:` / `behave-failed:` lines. See [Bisect](#bisect). |
| `--profile` / `--profile=N` | Print the top N slowest examples after the run (default `N=10`). Across multiple spec files the profile is a single global section after the `Overall:` counts. See [Timing](timing/timing.md#-profile). |
| `--slow-threshold=SECONDS` | Print an inline `SLOW` line under any example whose body takes at least `SECONDS` seconds. `SECONDS` may be fractional. See [Timing](timing/timing.md#-slow-threshold). |
| `--memory-profile` / `--memory-profile=N` | Track per-example RSS deltas and print the top N memory-heaviest examples after the run (default `N=10`). See [Memory profiling](timing/timing.md#memory-profiling). |
| `--memory-threshold=KB` | Print an inline `MEMORY` line under any example whose RSS delta meets or exceeds `KB` kilobytes. Enables measurement on its own. See [Memory profiling](timing/timing.md#memory-profiling). |
| `--format NAME`      | Select the output formatter for the run. `NAME` is the name of a registered formatter (`default` is built in). See [Formatters](formatter/formatter.md). |
| `--config PATH`      | Load Raku-based config from `PATH`. Skips the default `~/.behave` and `./.behave` lookups. See [Configuration](configuration/configuration.md). |
| `--no-config` / `--no-user-config` / `--no-project-config` | Skip all / user / project config files for this run. `BEHAVE_DISABLE_CONFIG=1` is equivalent to `--no-config`. See [Configuration](configuration/configuration.md). |

## Order and seed

Behave runs examples in **random order by default**. This shuffles the children of every `describe` / `context` group (and the top-level suite) before execution. Random ordering catches accidental order dependencies — examples that pass only because a sibling ran first — and is the recommended default.

When a run finishes, Behave prints the seed used so the order is reproducible:

```text
Overall: 1247 examples
  1236 passed
Randomized with seed 595739438
```

Pass `--seed N` to reproduce a specific order:

```shell
$ behave --seed 595739438
```

If random order surfaces a failure, the seed in the summary is all you need to re-run the same permutation.

### `--order defined`

For tests that intentionally depend on declaration order across sibling examples (cross-example accumulation, side-effect testing, hook-cascade verification), pass `--order defined`:

```shell
$ behave --order defined
```

No seed is auto-generated and no seed line is printed under defined order.

### Per-group order override

A single `describe` / `context` block can opt out of random order with `:order<defined>` metadata:

```raku
describe 'side-effecting hook cascade', :order<defined>, {
  my @log;
  before-each { @log.push('before') }

  it 'first example sees one before', {
    expect(@log.elems).to.be(1);
  }

  it 'second example sees two', {
    expect(@log.elems).to.be(2);
  }
}
```

`:order<defined>` inherits through nested groups, so an outer `:order<defined>` covers every descendant unless an inner group explicitly sets `:order<random>`.

### Programmatic use

`BDD::Behave::Runner::Runner.new` defaults to `:order<defined>` (deterministic) for programmatic / library use. `bin/behave` is what flips the user-facing default to `random`. Construct a Runner explicitly when you need a specific order:

```raku
my $runner = BDD::Behave::Runner::Runner.new(:order<random>, :seed(42));
```

`Runner.new(:order<sideways>)` (or any value other than `'random'` / `'defined'`) dies at construction time.

## Fail-fast

By default, Behave runs every example in the suite even after a failure, so the run produces a complete picture of what is broken. When iterating on a single problem — or when you want a faster signal in CI — pass `--fail-fast` to stop as soon as the first failure occurs:

```shell
$ behave --fail-fast
```

After the threshold is hit, Behave prints the normal failure list and counts, plus an abort banner:

```text
Aborted after 1 failure (--fail-fast)
```

Pass `--fail-fast=N` to keep running until `N` failures have accumulated:

```shell
$ behave --fail-fast=3
```

`N` must be a positive integer; `--fail-fast=0` and non-numeric values exit with a non-zero status and a helpful error on stderr.

When multiple spec files are passed on the command line, the threshold is shared across them — once it is reached, the remaining suites are not loaded. Skipped and pending examples do not count toward the threshold.

### Programmatic use

`BDD::Behave::Runner::Runner.new` accepts `:fail-fast(N)` (default `0`, meaning unbounded). The runner exposes `.aborted` (a `Bool`) after `.run` returns, so callers can distinguish a clean finish from an early abort:

```raku
my $runner = BDD::Behave::Runner::Runner.new(:fail-fast(1));
my $result = $runner.run($suite);
say 'aborted early' if $runner.aborted;
```

`Runner.new(:fail-fast(-1))` (or any negative integer) dies at construction time.

## Bisect

When a failure shows up only when a specific other example ran first — classic order-dependent test pollution — `--bisect` finds the minimal set of preceding examples needed to reproduce the failure.

```shell
$ behave --bisect
```

### What it does

1. **Initial pass** in declared order (`--order defined`); records which examples ran and which failed.
2. For each failing example, replays subsets of the prior examples in a fresh subprocess and shrinks the prior set until further pruning loses the failure.
3. Prints the minimal prior set and a ready-to-run reproduction command.

Each iteration spawns `bin/behave --bisect-data --order defined --only-example …` in a fresh subprocess, so user-code state (module-level vars, file handles, registries) cannot leak across iterations.

### Output

```text
==> Bisect: initial pass
Bisect: 1 failing example(s) found across 5 executed
  ✗ t/fixtures/bisect-fixture-spec.raku:29

==> Bisecting t/fixtures/bisect-fixture-spec.raku:29
  shrunk to 2 prior
  shrunk to 1 prior

  Minimal reproduction (1 prior + 1 failing):
    t/fixtures/bisect-fixture-spec.raku:20
    t/fixtures/bisect-fixture-spec.raku:29  (failing)

  Reproduce with:
    bin/behave --only-example t/fixtures/bisect-fixture-spec.raku:20 \
               --only-example t/fixtures/bisect-fixture-spec.raku:29 \
               --order defined t/fixtures/bisect-fixture-spec.raku

Bisect complete: 6 iteration(s)
```

If the failing example reproduces alone (no prior needed), Bisect reports `Failure reproduces in isolation — not order-dependent`. If the initial pass has no failures, Bisect exits 0 with `no failing examples`.

### `--only-example FILE:LINE`

`--only-example` is the targeting primitive Bisect uses to replay subsets. It is also useful directly:

```shell
$ behave --only-example specs/users-spec.raku:42
$ behave --only-example users-spec.raku:42 specs/users-spec.raku  # basename match
```

`FILE` matches if any of these hold: exact-string equality with the example's stored path, absolute-path equality, `path/to/file.raku` suffix match, or basename equality. `LINE` must equal the line of the `it` block. Repeating `--only-example` is OR semantics; the runner runs every example matching any pattern.

### `--bisect-data`

Used by `--bisect` for inter-process communication and exposed for editor/tool integrations that want a parseable listing of executed and failed examples:

```text
behave-executed: specs/users-spec.raku:12
behave-executed: specs/users-spec.raku:24
behave-failed: specs/users-spec.raku:24
```

`--bisect-data` suppresses normal output. It is mutually exclusive with `--bisect`.

### Limits

- Bisect uses `--order defined` for sub-runs. Failures that only reproduce under a specific random `--seed` need to be diagnosed differently — re-run with the failing seed and `--order defined` after locking in the order.
- Sub-runs use the same `--tag`, `--exclude-tag`, `--example`, and `--aggregate-failures` you passed to `bin/behave --bisect`.
- The shrink uses binary halving first, then one-at-a-time minimization when halving stalls. Iteration count grows roughly with `log(prior) + minimal-prior-count`.

## Filtering by description

`--example PATTERN` (alias `-e`) runs only examples whose full nested description matches `PATTERN` (substring or `/regex/`). See [Example Filter](example-filter/example-filter.md) for the full reference, including how it composes with `--tag`.

## Output

Behave prints each describe/context with a `⮑` marker, indenting nested groups, and reports `SUCCESS` / `FAILURE` / `PENDING` / `SKIPPED` per example. See [Focus and Skip](focus-skip/focus-skip.md) for `xit` / `fit` / `xdescribe` / `fdescribe`. After all specs run it prints a summary like:

```
============================================================
Overall: 96 examples
  96 passed
```

## Exit code

`behave` exits `0` if every example passed, `1` if any example failed.
