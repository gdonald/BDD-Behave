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
  $c.coverage-include-path('lib/');
  $c.coverage-exclude-path('lib/vendor');
}
```

CLI flags override config-file values. List-style options
(`coverage-include-path`, `coverage-exclude-path`) accumulate across config
layers and the CLI.

## How it works

`--coverage` sets `MVM_COVERAGE_LOG` and `MVM_COVERAGE_CONTROL=2` in a child
process that runs the same `bin/behave` invocation. MoarVM writes one `HIT`
line per executed source line to a temp file under `$TMPDIR`. When the child
exits, the parent runs `grep -F` over that file to keep only lines matching
the include patterns, parses the filtered result, and renders the report.

Under `--parallel`, the wrapper is skipped: the parallel parent gives each
worker its own `MVM_COVERAGE_LOG` path
(`$TMPDIR/behave-coverage-parallel-<pid>-<stamp>/worker-N.raw`), and after
the workers exit it merges every per-worker log into a single hit map (set
union, since coverage records *whether* a line was hit). The same report
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
