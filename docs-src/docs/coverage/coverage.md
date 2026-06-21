# Code Coverage

Behave can track which lines of your application code execute during a spec run
and report what percentage was covered. Pass `--coverage` to `bin/behave`, and
Behave re-runs your specs as a subprocess with MoarVM's per-line coverage
logging enabled, parses the resulting log, and prints a report.

```bash
behave --coverage specs/
```

By default, only files under `lib/` (relative to the working directory) are
tracked. Use `--coverage-include` / `--coverage-exclude` to change the scope.

## Output formats

`--coverage-format=FORMAT` selects the report format. Available formats:

| Format      | Best for                                                              |
| ----------- | --------------------------------------------------------------------- |
| `html`      | Browsable per-file report with green/red line highlighting (default). |
| `text`      | Colored per-file coverage summary printed to the terminal.            |
| `json`      | Machine-readable. Also the baseline format for `--coverage-baseline`. |
| `lcov`      | `genhtml`, Codecov, Coveralls.                                        |
| `cobertura` | Jenkins, GitLab CI, Azure DevOps.                                     |

```bash
behave --coverage specs/                            # writes ./coverage/ (html)
behave --coverage --coverage-format=text specs/     # terminal summary
behave --coverage --coverage-format=json --coverage-output=coverage.json specs/
behave --coverage --coverage-format=lcov --coverage-output=coverage.lcov specs/
```

`--coverage-output=PATH` writes the report to PATH instead of stdout.
**`html` is special**: PATH is a *directory* (default `./coverage/`) that
Behave fills with `index.html`, `style.css`, and one HTML page per source
file. The index is the entry point: open `coverage/index.html`.

## Hit counts

By default behave records only whether each line ran, using the lighter
`MVM_COVERAGE_CONTROL=0` mode whose log deduplicates repeated hits at the
source. Pass `--coverage-counts` to record how many times each line executed
instead. This runs the heavier `MVM_COVERAGE_CONTROL=2` mode (every execution
is logged) and adds hit counts to the report:

```bash
behave --coverage --coverage-counts specs/
```

- **text** and **html index**: a `Hits` column showing each file's total
  executions across its covered lines.
- **html file page**: a per-line count gutter beside the source.
- **json**: a `total-hits` value per file plus a `line-hits` map of line
  number to count.

`--coverage-counts` is slower than the default because the raw log grows with
every line transition rather than collapsing to one row per line. Use it when
you want an execution heatmap, not just covered/uncovered.

## Filtering tracked files

`--coverage-include=PATH` restricts the report to files whose path **starts
with** PATH. Repeatable. Multiple includes combine with OR. The prefix
semantics are deliberate: they mean a default of `lib/` matches the relative
paths your specs load via `-Ilib` while excluding Rakudo/NQP internals
(`/Users/.../rakudo/share/nqp/lib/...`) that happen to contain `lib/` in the
middle of an absolute path.

`--coverage-exclude=PATH` removes files whose path **contains** PATH
(substring match). Repeatable. An exclude match wins over an include match.

```bash
behave --coverage --coverage-include=lib/BDD --coverage-exclude=lib/BDD/Vendor specs/
```

When no `--coverage-include` is passed, Behave includes `lib/` by default.

## Excluding lines with nocov markers

To drop a region of a source file from coverage, wrap it in a pair of
`# :nocov:` comment markers. The marker must be the only content on its line
(a `#`, optional whitespace, then `:nocov:`). Lines between the opening and
closing marker count as neither covered nor missed, so they do not lower the
percentage and render neutral in the HTML report.

```raku
sub parse-record($line) {
  my $parsed = decode($line);

  # :nocov:
  unless $parsed.defined {
    die "unreachable: decode never returns an undefined value";
  }
  # :nocov:

  $parsed;
}
```

An opening marker with no matching closer excludes everything through the end
of the file. The markers belong in the implementation files being measured,
not in specs. They apply to both line coverage and `--coverage-branch`, so a
branch line inside a nocov block is not counted as a branch.

## Thresholds

`--coverage-minimum=PCT` fails the run when overall line coverage is below PCT
(a number between 0 and 100). The behave exit code is non-zero when the
threshold is not met, even if every spec passed. Useful as a CI gate.

```bash
behave --coverage --coverage-minimum=85 specs/
```

## Branch coverage

`--coverage-branch` adds a second line to the summary that reports how many
branching constructs (`if`, `elsif`, `unless`, `with`, `without`, `when`,
`while`, `until`, `given`, `for`) were exercised by the run.

```bash
behave --coverage --coverage-branch specs/
```

The branch metric is also emitted in JSON, LCOV (`BRF` / `BRH` / `BRDA`), and
Cobertura output.

## Comparing against a baseline

A previous JSON coverage report can be passed via `--coverage-baseline=PATH`,
and Behave will print a per-file diff (newly covered lines, newly uncovered
lines, regressed files, improved files).

```bash
# Capture a baseline once
behave --coverage --coverage-format=json --coverage-output=baseline.json specs/

# Later: compare current state against it
behave --coverage --coverage-baseline=baseline.json specs/
```

This pairs naturally with `--coverage-minimum`: in CI, keep `baseline.json`
checked in and surface a regression when coverage drops in a PR.

## Configuration file

Coverage flags can also live in a `.behave` config file (project or user):

```raku
use BDD::Behave::Configuration;

configure-behave -> $c {
  $c.coverage         = True;
  $c.coverage-minimum = 80;
  $c.coverage-format  = 'text';
  $c.coverage-branch  = True;
  $c.coverage-counts  = True;
  $c.coverage-include-path('lib/');
  $c.coverage-exclude-path('lib/vendor');
}
```

CLI flags override config-file values. List-style options
(`coverage-include-path`, `coverage-exclude-path`) accumulate across config
layers and the CLI.

## How it works

`--coverage` sets `MVM_COVERAGE_LOG` and `MVM_COVERAGE_CONTROL` in a child
process that runs the same `bin/behave` invocation. MoarVM writes a `HIT` line
to a temp file under `$TMPDIR` for each executed source line. The default
control mode `0` deduplicates at the source, so each line appears about once;
`--coverage-counts` switches to mode `2`, which logs every execution (a hot
line can then appear millions of times). When the child exits, the parent runs
`grep -F` over that file to keep only lines matching the include patterns, then
`awk` tallies the matches into one row per unique line prefixed with its
occurrence count. This keeps the filtered log small. The parent parses the
tallied result and renders the report.

On a full suite the raw log can take a while to filter. When stderr is a
terminal, Behave streams the raw bytes through the filter itself and draws a
single continuously updated progress line with a percent, a bar, and a rough
ETA based on bytes processed over elapsed time. Off a terminal (CI, piped
output) the filter reads the files directly and prints nothing.

Under `--parallel`, the wrapper is skipped: the parallel parent gives each
worker its own `MVM_COVERAGE_LOG` path
(`$TMPDIR/behave-coverage-parallel-<pid>-<stamp>/worker-N.raw`), and after
the workers exit it tallies every per-worker log together in a single `awk`
pass, unioning each line's hits across workers (and summing the counts when
`--coverage-counts` is in effect). The same report
pipeline then renders one combined report against the merged data.
`--coverage-minimum` is gated on the merged percentage. See
[Coverage under --parallel](../parallel/parallel.md#coverage) in the parallel
guide for the full description.

Executable line counts are derived from a static read of each source file:
blank lines, comments, lines that contain only closing punctuation (`}`,
`)`, etc.), lines inside `=begin pod` / `=end pod` blocks, and lines between
`# :nocov:` markers are ignored.

## Limitations

- macOS and Linux only. Relies on `grep` in `PATH`.
- Coverage runs are slower than ordinary runs because MoarVM logs every
  executed line in user code (including Rakudo's startup path). The raw
  log can reach several GB under `$TMPDIR` for a full-suite run. It is
  unlinked once the report is generated.
- Branch coverage is line-based: a single `if` line that contains both
  branches inline counts as one branch.
