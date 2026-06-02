# Timing

Behave records how long each example takes to run. Timing data lives on the
`Example` node itself, so any consumer that walks the spec tree after a run
(formatters, reporters) can read it directly.

## What is captured

For every example that the runner actually executes, three values are
recorded:

- `started-at`: an `Instant` taken immediately before the example body runs.
- `finished-at`: an `Instant` taken immediately after the body completes,
  whether it passed or raised an exception.
- `duration`: `finished-at - started-at`, expressed as a `Real` in seconds.

The capture is scoped to the example body. Hooks (`before-each`,
`after-each`, `around-each`) run outside this window, so their cost is not
counted toward the example duration.

## What is not captured

The timing slots stay undefined for examples that never run:

- **Pending examples** never enter the body, so `duration`, `started-at`,
  and `finished-at` remain undefined.
- **Skipped examples** (`xit`, `xdescribe`, `:skipped` metadata,
  filter-skipped via `--tag` / `--exclude-tag` / `--example`) likewise
  remain untouched.
- Examples bypassed by an `around-each` continuation that never invokes
  its block stay untouched.

## Reading the values

```raku
use BDD::Behave::Runner;
use BDD::Behave::SpecTree;

sub walk-examples($node, &visit) {
    given $node {
        when BDD::Behave::SpecTree::Example { visit($node) }
        default {
            for $node.children -> $child {
                walk-examples($child, &visit);
            }
        }
    }
}

my $runner = BDD::Behave::Runner::Runner.new;
$runner.run($suite);

walk-examples $suite, -> $ex {
    next unless $ex.duration.defined;
    say "{$ex.description}: {$ex.duration} s";
};
```

Failures are still timed. A `die` inside an example body produces a
`duration` reflecting the wall time spent before the exception propagated.

## --profile

`behave --profile` prints a "Top N slowest examples" section at the end of
the run. The default is `N=10`. Pass `--profile=N` to choose a different
size. Examples are sorted by `duration` (descending) and the section's
total is the sum of the listed examples' durations.

```text
Top 3 slowest examples (0.187s total):
  0.120s  profile-fixture c slow example
          t/fixtures/profile-fixture-spec.raku:11
  0.052s  profile-fixture b medium example
          t/fixtures/profile-fixture-spec.raku:6
  0.015s  profile-fixture a fast example
          t/fixtures/profile-fixture-spec.raku:2
```

When multiple spec files run, `--profile` aggregates timings across all
files and prints a single global section after the `Overall:` counts.

Pending and skipped examples are not eligible for the profile. Only
examples whose body actually ran are listed.

## --slow-threshold

`behave --slow-threshold=SECONDS` prints an inline `SLOW (Xs, threshold
Ys)` line under each example whose duration meets or exceeds `SECONDS`.
`SECONDS` may be fractional (`0.075`).

```text
⮑  'c slow example'
  ⮑  SUCCESS
  ⮑  SLOW (0.121s, threshold 0.010s)
```

The threshold is opt-in: without `--slow-threshold` no `SLOW` lines are
printed. The flag composes with `--profile`: `--slow-threshold` flags slow
examples inline as the run progresses. `--profile` lists the top N at the
end.

Construction-time validation: `Runner.new(:profile-limit(-1))` and
`Runner.new(:slow-threshold(-1))` both die. Both knobs require a
non-negative value, with `0` meaning disabled.

## Programmatic access

`Runner` exposes `@.timed-examples`, a list of `Hash` records, one per
executed example:

```raku
$runner.run($suite);
for $runner.timed-examples -> %rec {
    say "{%rec<duration>}s  {%rec<description>}";
}
```

Each record carries `example` (the `Example` node), `description` (the
full nested description), and `duration` (a `Real` in seconds). Pending,
skipped, and around-skipped examples are not added.

The same `print-profile(Int $limit, @records?)` method that `--profile`
uses is public. Callers can pass a custom record list to print a profile
across an aggregated run.

## Benchmarking

`benchmark { ... }` runs a block N times inside an example body and
captures min, max, mean, median, and total timings across the
iterations. The result is returned to the caller and also pushed onto
the example's `benchmarks` slot for later inspection by reporters.

```raku
use BDD::Behave;

describe 'sum', {
    it 'is reasonably fast', {
        my $r = benchmark :iterations(1000), { (1..100).sum };
        expect($r.median).to.be-less-than(0.001);
    }
}
```

### Calling conventions

Two forms are supported:

```raku
benchmark { code }
benchmark :iterations(50), :warmup(10), :label('hashing'), { code }
benchmark 'hashing', :iterations(50), { code }
```

The first positional `Str` (if present) becomes the label. The block is
always the trailing positional argument.

### Named options

- `iterations` (`Int`, default `100`): number of timed runs. Must be a
  positive integer. `0` or negative values raise an exception.
- `warmup` (`Int`, default `0`): number of untimed warmup runs to
  execute before measurement begins. Useful for letting JIT, caches, or
  module-level lazy-init settle. Must be `0` or positive.
- `label` (`Str`, optional): identifies the benchmark when an example
  contains more than one. Equivalent to passing the label as the first
  positional argument.

### Result shape

`benchmark` returns a `BDD::Behave::Benchmark::BenchmarkResult`:

| Field          | Type      | Meaning                                |
|----------------|-----------|----------------------------------------|
| `label`        | `Str`     | label passed in, or undefined          |
| `iterations`   | `Int`     | number of timed runs                   |
| `timings`      | `List`    | per-iteration seconds (`Real`)         |
| `min`          | `Real`    | smallest per-iteration timing          |
| `max`          | `Real`    | largest per-iteration timing           |
| `mean`         | `Real`    | `total / iterations`                   |
| `median`       | `Real`    | middle value (or average of two middles for even N) |
| `total`        | `Real`    | sum of timings                         |

### Attachment to the example

When `benchmark` is called from within an example body, the result is
also pushed onto `example.benchmarks`. Multiple `benchmark` calls in a
single example accumulate in declaration order, so a reporter can walk
`example.benchmarks` after the run to surface every measurement.

Pending and skipped examples never enter the body, so their
`benchmarks` slot stays empty. Calling `benchmark` outside an example
still returns a valid result, but nothing is attached.

The example also exposes `started-at`, `finished-at`, and `duration`
slots (see above). A benchmark's `total` is normally a fraction of
`duration`, with the rest accounted for by the test scaffolding and any
non-benchmarked work the body does.

### --benchmark mode

`behave --benchmark` walks the suite, finds every example that called
`benchmark { ... }`, aggregates the per-call results, and prints a
`Benchmarks` section at the end of the run:

```text
Benchmarks (3 measurements):
  benchmark-fixture measures a sum  [label:sum]
          t/fixtures/benchmark-fixture-spec.raku:4
    iterations=3  min=0.000005s  max=0.000207s  mean=0.000074s  median=0.000009s
  benchmark-fixture measures two labeled calls  [label:a]
          t/fixtures/benchmark-fixture-spec.raku:9
    iterations=2  min=0.000002s  max=0.000003s  mean=0.000002s  median=0.000002s
```

Each row keys on `(full nested description, label or position)`. A
labeled `benchmark('foo', { ... })` becomes `label:foo`. An unlabeled
call becomes `pos:N`, where `N` is the call's 0-based order within the
example body. Position resets per body invocation (so `--benchmark-iterations`
re-runs do not collide), so prefer labels when an example contains more
than one unlabeled benchmark.

### --benchmark-iterations

`behave --benchmark-iterations=N` re-runs every benchmarked example
`N` times (1 = no re-runs, the default) inside the same process,
aggregating all per-call timings under one summary row. Re-runs are
silent: their output is suppressed and they do **not** add to the
passed / failed / skipped counts.

```text
behave --benchmark-iterations=5 specs/
```

Each re-run goes through `handle-example`, so `before-each`,
`after-each`, and `around-each` hooks fire normally (and so do lets).
This matches the cost profile of the example as it would run in the
suite, which is the right baseline for benchmark measurements.

### --benchmark-baseline / --benchmark-save

`behave --benchmark-save=PATH` writes the current run's benchmark
medians to `PATH`. `behave --benchmark-baseline=PATH` reads the file
back and adds a comparison block under the Benchmarks section:

```text
Benchmark regressions (1, threshold 10.0%):
  ... [label:sum]   median 0.000006s (baseline 0.000007s)   -14.1%
  ... [label:a]     median 0.000003s (baseline 0.000002s)   +34.0% REGRESSION
  ... [label:b]     median 0.000002s (baseline 0.000002s)   +7.1%
```

A row is flagged `REGRESSION` when `(current.median - baseline.median) /
baseline.median > threshold`. The default threshold is `0.10` (10%).
Override it with `--benchmark-threshold=PCT` (decimal fraction,
e.g. `--benchmark-threshold=0.20` for 20%).

The header phrasing depends on whether anything was flagged:
`Benchmark regressions (N, threshold X%)` (red) when at least one row
exceeded the threshold, or `Benchmark comparison (no regressions;
threshold X%)` otherwise. Rows with no matching baseline entry are
silently dropped. Rows whose baseline matched are listed even if they
did not regress, so you can see the percentage change on every measured
benchmark.

Both `--benchmark-baseline` and `--benchmark-save` imply `--benchmark`
on their own. You do not have to pass both flags.

#### Baseline file format

The baseline is a plain-text, tab-separated file with two header lines:

```text
# behave-benchmark-baseline v1
description	key	iterations	min	max	mean	median	total
benchmark-fixture measures a sum	label:sum	3	0.000003792	...
benchmark-fixture measures two labeled calls	label:a	2	0.000001666	...
```

It's diff-friendly, free of any embedded code, and parsed without
`EVAL`. Keys match the same `(description, key)` shape as the
in-memory summary, so renaming a `describe`/`context`/`it` will detach
its baseline entry (which is then silently dropped). Lines starting
with `#` are treated as comments and ignored after the header.

### Multi-file runs

When `behave` is given more than one spec file, per-file Runners run
in benchmark mode silently and accumulate their summaries. The CLI
prints **one** combined Benchmarks section after the `Overall:` counts.
The baseline comparison and `--benchmark-save` likewise run once over
the combined summary set, so a baseline file captures every benchmark
in the run, not just those from the last file.

### Programmatic access

```raku
my $runner = BDD::Behave::Runner::Runner.new(
    :benchmark-mode,
    :benchmark-iterations(5),
    :benchmark-baseline('baseline.txt'.IO),
    :benchmark-threshold(0.10),
);
$runner.run($suite);

for $runner.benchmark-summaries -> %s {
    say "{%s<description>} [{%s<key>}]  median={%s<median>}s";
}

for $runner.benchmark-regressions.grep(*<regression>) -> %r {
    note "REGRESSION: {%r<description>} {%r<key>}  +{(%r<delta-pct> * 100).fmt('%.1f')}%";
}
```

`benchmark-summaries` is a List of Hash records (`example`,
`description`, `key`, `label`, `position`, `runs`, `iterations`,
`timings`, `min`, `max`, `mean`, `median`, `total`).
`benchmark-regressions` adds `baseline-median`, `baseline-mean`,
`delta-pct`, and `regression` (Bool). Construction-time validation:
`benchmark-iterations` must be a positive integer, and
`benchmark-threshold` must be `>= 0`. Both die with a clear message
otherwise.

### Output formatting

The Benchmarks section renders as a pretty table by default with
aligned columns, a horizontal rule under the header, and one row per
measurement:

```text
Benchmarks (3 measurements):
  DESCRIPTION                                   KEY        ITER    MIN(s)    MAX(s)   MEAN(s)  MEDIAN(s)
  ────────────────────────────────────────────  ─────────  ────  ────────  ────────  ────────  ─────────
  benchmark-fixture measures a sum              label:sum     3  0.000004  0.000176  0.000062   0.000006
  benchmark-fixture measures two labeled calls  label:a       2  0.000002  0.000003  0.000002   0.000002
  benchmark-fixture measures two labeled calls  label:b       2  0.000002  0.000003  0.000002   0.000002
```

When a baseline comparison is active, a second table appears under it
with comparison arrows:

```text
Benchmark regressions (1, threshold 10.0%):
  DESCRIPTION                                   KEY         BASELINE    CURRENT  DELTA
  ────────────────────────────────────────────  ─────────  ─────────  ─────────  ───────────────────
  benchmark-fixture measures a sum              label:sum  0.000006s  0.000007s  ↑ +11.0% REGRESSION
  benchmark-fixture measures two labeled calls  label:a    0.000002s  0.000002s  ↓ -1.8%
  benchmark-fixture measures two labeled calls  label:b    0.000002s  0.000002s  → +0.0%
```

Arrows mean:

- `↑`: current is slower than baseline. When the delta exceeds
  `--benchmark-threshold`, the row is also colored red and tagged
  `REGRESSION`.
- `↓`: current is faster than baseline. When the absolute delta
  exceeds `--benchmark-threshold`, the row is also colored green to
  highlight a real improvement.
- `→`: exactly zero delta (or extremely close).

The arrow always reflects direction. The color reflects whether the
delta crossed the threshold in either direction.

#### --benchmark-format

`behave --benchmark-format=FORMAT` chooses how the Benchmarks section
is rendered. Supported values:

- `text` (default): the pretty tables shown above.
- `json`: a single JSON object suitable for CI dashboards. Keys are
  sorted alphabetically for a stable diff. Numbers render in their
  natural Raku string form. Strings are JSON-escaped.

Setting `--benchmark-format` to anything else exits 2 with a clear
error. Setting it to `json` (or any non-`text` value) auto-enables
`--benchmark`.

The JSON shape:

```json
{
  "benchmarks": [
    {
      "description": "...",
      "file": "...",
      "iterations": 3,
      "key": "label:sum",
      "label": "sum",
      "line": 4,
      "max": 0.000176,
      "mean": 0.000062,
      "median": 0.000006,
      "min": 0.000004,
      "position": 0,
      "runs": 1,
      "total": 0.00018571
    }
  ],
  "regressions": [
    {
      "baseline-median": 0.000007,
      "current-median": 0.000006,
      "delta-pct": -0.141,
      "description": "...",
      "key": "label:sum",
      "regression": false
    }
  ],
  "threshold": 0.1,
  "version": 1
}
```

`benchmarks[]` always has one entry per current measurement.
`regressions[]` is empty unless `--benchmark-baseline` is set, in
which case it has one entry per baseline match (or empty if no entries
matched).

#### --benchmark-output

`behave --benchmark-output=PATH` writes the Benchmarks section to a
file instead of stdout. Useful with `--benchmark-format=json` so a CI
pipeline can ingest the JSON without parsing it out of test output:

```bash
behave --benchmark --benchmark-format=json \
       --benchmark-output=benchmarks.json specs/
```

`--benchmark-output` works with text format too, and on its own
auto-enables `--benchmark`. The stdout test output is unaffected.

#### Programmatic access

`Runner.render-benchmark-output(@summaries, @regressions, :$threshold,
:$format)` returns the formatted string without printing it, for
callers that want to embed the output somewhere else.
`Runner.render-bench-summary-table` and
`Runner.render-bench-comparison-table` are the underlying helpers if
you only need one of the two tables. The JSON serializer is exposed as
`BDD::Behave::Benchmark::Format::to-json($value)`. It supports `Bool`,
`Numeric`, `Str`, `Positional`, `Associative` (keys sorted), and falls
back to `null` for undefined values.
