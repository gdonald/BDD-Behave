# Formatters

Behave's runner is decoupled from its output: every line it prints is emitted through a **formatter**. The default selection (when `--format` is not given) is `progress` (compact dot-stream output). You can swap in any class that composes the `BDD::Behave::Formatter` role to render runs differently: indented tree, hierarchical documentation, JSON, JUnit XML, and so on.

## Selecting a formatter

Pass `--format NAME` to `behave`:

```shell
$ behave --format tree specs/users-spec.raku
```

`NAME` must be a registered formatter. The built-in formatters are `documentation`, `html`, `json`, `json-events`, `junit`, `progress`, `tap`, and `tree`. (`json-events` is the line-delimited event stream parallel workers use to report back to the parent. It is registered and selectable but rarely useful on its own.) An unknown name fails fast:

```text
$ behave --format nope
Error: unknown --format 'nope' (available: documentation, html, json, json-events, junit, progress, tap, tree)
```

When `--format` is omitted, `progress` is selected. The currently registered names are also listed in `behave --help`.

## Built-in formatters

### `progress`

The default. Compact single-line output, one character per example. See the dedicated entry below.

### `tree`

Behave's classic indented tree output (formerly called `default`): one line per `describe`/`context`/`it`, a green `SUCCESS` / red `FAILURE` marker per example, and inline `SLOW` / `MEMORY` annotations when `--slow-threshold` / `--memory-threshold` fire. Useful for debugging: you can see exactly which example is running when something hangs or hits a long step.

### `documentation`

A clean, document-style rendering of the spec tree. Each `describe`/`context` is printed as a heading (no quotes, no arrow markers) and each example is printed as an indented line beneath its enclosing group. Non-passing outcomes get a parenthetical suffix:

| Outcome  | Suffix |
| -------- | ------ |
| Pass     | *(none: description prints on its own)* |
| Fail     | `(FAILED)` |
| Pending  | `(PENDING)` |
| Skipped  | `(SKIPPED)` |
| Around-skipped | `(SKIPPED: around-each did not invoke continuation)` |

The `Failures:` block, counts line, profile/memory/benchmark sections, and the multi-file `Overall:` block all print exactly as they do under `tree`, except in multi-file mode the per-file `Failures:` + counts line is deferred. Every spec file's tree streams uninterrupted under its own filename heading, and a single `Failures:` block plus the `Overall:` counts print once at the end.

```text
$ behave --format documentation specs/calc-spec.raku
Calculator
  addition
    adds two positive numbers
    overflows on MAX_INT (FAILED)
    handles negative-zero (PENDING)
  subtraction
    subtracts a positive from a positive

Failures:

  [ ✗ ] specs/calc-spec.raku:24
      Expected: 2147483648
      to be: -2147483648

5 examples, 1 failed, 1 pending, 3 passed
```

### `html`

A self-contained HTML5 report with collapsible `describe`/`context` nesting (native `<details>`/`<summary>`, no JavaScript required) and color-coded examples. Designed to be redirected to a file and opened in a browser:

```shell
$ behave --format html specs/ > report.html
$ open report.html
```

Structure:

| Element | Role |
| ------- | ---- |
| `<p class="summary">` / `<p class="summary has-failures">` | Counts line at the top, with `has-failures` styling when any example failed. |
| `<details open class="group">` / `<summary class="group-summary">` | One per `describe`/`context`. Open by default. Click to collapse. |
| `<div class="example pass">` / `.fail` / `.pending` / `.skipped` | Per-example row with a marker (`✓`/`✗`/`⏸`/`⊘`), the description, duration, and source location. |
| `<pre class="failure-detail">` | Failure body for failing examples (also used for pending reason and `around-each` skip reason). |
| `<div class="load-error">` | One per spec file that failed to compile. |

Inline `<style>` provides the default theme. Colors are hard-coded (no external CSS). All user descriptions and file paths are HTML-escaped (`<`, `>`, `&`, `"`). In multi-file mode every spec file gets an `<h2 class="suite-file">` heading and a single HTML document covers the entire run.

### `json`

Emits a single JSON document on stdout after the run finishes, designed for CI dashboards and tool integration. No per-example or per-group output is printed, so the document is the only thing on stdout (load errors and CLI flag errors are still emitted to stderr as usual).

Top-level shape:

```json
{
  "version": 1,
  "order": "random",
  "seed": 42,
  "aborted": false,
  "examples": [...],
  "load_errors": [...],
  "summary": {
    "total": 5,
    "passed": 2,
    "failed": 1,
    "pending": 1,
    "skipped": 1,
    "duration": 0.045
  },
  "summary_line": "5 examples, 1 failed, 1 pending, 1 skipped, 2 passed"
}
```

Each entry in `examples` carries:

| Field | Description |
| ----- | ----------- |
| `description` | The `it`/`pending`/`xit` description (or the derived label for the `it { ... }` form). |
| `full_description` | The description prefixed with the enclosing `describe`/`context` chain. |
| `status` | `"passed"`, `"failed"`, `"pending"`, or `"skipped"`. |
| `file`, `line` | Source location. |
| `duration` | Seconds (or `null` for pending/skipped). |
| `memory_delta` | KB (or `null` when memory profiling is off). |
| `tags` | Effective tag list (inherits from enclosing groups). |
| `failure` | Present only for `status: "failed"`. Carries `type: "exception"` with `message` when the body threw, and/or an `expectations` array with `file`, `line`, `given`, `expected`, `negated`, and an optional `message`/`aggregation_label`. |
| `pending_reason` | Present only for `status: "pending"`. The reason string passed to `pending`. |
| `skip_reason` | Present only when `around-each` returned without invoking its continuation. |

In multi-file mode the document is emitted once, after every spec file has run, with `summary` reflecting the merged counts. Per-suite intermediate emission is suppressed.

### `junit`

JUnit XML format consumable by Jenkins, GitLab CI, CircleCI, and other CI dashboards that ingest the `testsuites`/`testsuite`/`testcase` schema.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<testsuites name="behave" tests="5" failures="1" errors="0" skipped="2" time="0.045000">
  <testsuite name="calc-spec.raku" tests="5" failures="1" errors="0" skipped="2" time="0.045000" timestamp="..." file="specs/calc-spec.raku">
    <testcase classname="Calculator" name="adds positive numbers" file="specs/calc-spec.raku" line="4" time="0.001000"/>
    <testcase classname="Calculator &gt; addition" name="overflows" file="specs/calc-spec.raku" line="9" time="0.001000">
      <failure type="Expectation" message="Expected 2147483648 to be -2147483648"><![CDATA[
specs/calc-spec.raku:9
  Expected: 2147483648
  to be:    -2147483648
      ]]></failure>
    </testcase>
    <testcase classname="Calculator" name="todo" file="specs/calc-spec.raku" line="12" time="0.000000">
      <skipped message="pending: not yet implemented"/>
    </testcase>
  </testsuite>
</testsuites>
```

Conventions:

| Outcome | Child element | Notes |
| ------- | ------------- | ----- |
| Pass    | *(self-closing testcase)* | |
| Failure (expectation) | `<failure type="Expectation" message="..."><![CDATA[...]]></failure>` | Message summarizes the first failed expectation. CDATA body contains all expectations for the example (file:line + given/expected). |
| Failure (exception)   | `<error type="Exception" message="..."><![CDATA[...]]></error>` | Used when the example body threw. Message comes from `Exception.message`. |
| Pending | `<skipped message="pending: REASON"/>` | |
| Skipped | `<skipped message="skipped"/>` | |
| Around-skipped | `<skipped message="around-each did not invoke continuation"/>` | |

The `classname` attribute joins the enclosing `describe`/`context` chain with ` > ` so CI dashboards that group by class produce a sensible hierarchy. Special characters (`<`, `>`, `&`, `"`, `'`) in attribute values are XML-escaped. CDATA bodies have `]]>` re-encoded as `]]]]><![CDATA[>` so they survive arbitrary payloads. In multi-file mode every spec file produces its own `<testsuite>` element under a single `<testsuites>` root.

### `tap`

[Test Anything Protocol](https://testanything.org/) version 13 output for compatibility with TAP consumers (`prove`, `tappy`, etc.):

```text
TAP version 13
1..5
ok 1 - Calculator addition adds positive numbers
not ok 2 - Calculator addition overflows on MAX_INT
  ---
  severity: 'fail'
  file: 'specs/calc-spec.raku'
  line: 24
  message: 'Expected 2147483648 to be -2147483648'
  got: '2147483648'
  expected: '-2147483648'
  ...
ok 3 - Calculator addition handles negative-zero # TODO not yet implemented
ok 4 - Calculator addition obsoleted # SKIP skipped
ok 5 - Calculator subtraction subtracts a positive from a positive
```

Conventions:

| Outcome | Line | Notes |
| ------- | ---- | ----- |
| Pass    | `ok N - DESCRIPTION` | |
| Failure (expectation) | `not ok N - DESCRIPTION` + YAML diagnostic block | YAML carries `severity: 'fail'`, `file`, `line`, `message`, `got`, `expected`. |
| Failure (exception)   | `not ok N - DESCRIPTION` + YAML diagnostic block | YAML carries `severity: 'error'`, `message` (the exception message). |
| Pending | `ok N - DESCRIPTION # TODO REASON` | TAP TODO directive (TAP consumers treat these as expected-fail, not failures). |
| Skipped | `ok N - DESCRIPTION # SKIP skipped` | |
| Around-skipped | `ok N - DESCRIPTION # SKIP around-each did not invoke continuation` | |

The full describe/context chain is prefixed onto each description (joined by spaces). `#` characters embedded in user descriptions are escaped as `\#` so a TAP parser cannot mistake them for the start of a directive. In multi-file mode a single TAP document covers all spec files (one plan line, one numbering sequence).

### `progress`

Compact single-line output, one character per example:

| Character | Meaning |
| --------- | ------- |
| `.`       | Pass    |
| `F`       | Failure |
| `*`       | Pending |
| `S`       | Skipped (`xit`/`xdescribe`/`xcontext` or `:skipped`, and `around-each`/`around-all` that returned without invoking their continuation) |

Group descriptions, `it` descriptions, and inline slow/memory markers are suppressed. The failures detail block, counts line, profile/memory/benchmark sections, and the multi-file `Overall:` block still print exactly as they do under `tree`, except in multi-file mode the per-file `Failures:` + counts line is deferred. Dots stream continuously across every spec file, then a single `Failures:` block plus the `Overall:` counts print once at the end.

```text
$ behave --format progress specs/
.....FF*.S....

Failures:

  [ ✗ ] specs/calc-spec.raku:24
      Expected: 1
      to be: 2
  [ ✗ ] specs/db-spec.raku:11
      exception in Database connect refuses without credentials: connection refused

14 examples, 2 failed, 1 pending, 1 skipped, 10 passed
```

Both expectation mismatches and exception-based failures (an example body that `die`s or throws) appear in the `Failures:` block with their source `file:line`, so a `progress` run is enough to diagnose what to fix without re-running under `tree`.

## The `BDD::Behave::Formatter` role

`BDD::Behave::Formatter` is a Raku role that declares a hook for every interesting event the runner emits. All hooks have no-op default bodies, so custom formatters only need to override the events they care about.

### Lifecycle hooks

| Hook | When it fires |
| ---- | ------------- |
| `suite-loading(:$file)` | Before a spec file is loaded (verbose mode only). |
| `suite-start($suite, :$multi-file)` | Once per spec file, before its suite runs. `:multi-file` is true when more than one file was selected. |
| `suite-end($suite)` | After a suite completes. |
| `group-start($group)` / `group-end($group)` | Around every `describe` / `context` group. |
| `group-around-skipped($group)` | When an `around-all` hook returned without invoking its continuation. |
| `example-start($example, :$auto)` | Before an example body executes. `:auto` is true when the example will have its description derived from a matcher (`it { ... }`). |
| `example-auto-description($example, :$description)` | After an auto-described example finishes, with the derived description. |
| `example-pass($example)` / `example-fail($example, :$failure-info)` / `example-pending($example)` / `example-skipped($example)` | Per-example outcomes. |
| `example-around-skipped($example)` | When an `around-each` hook returned without invoking its continuation. |
| `example-slow($example, :$threshold)` | When an example's duration meets or exceeds `--slow-threshold`. |
| `example-memory-leak($example, :$threshold)` | When an example's RSS delta meets or exceeds `--memory-threshold`. |

### Summary hooks

| Hook | When it fires |
| ---- | ------------- |
| `run-summary($result, :$aborted, :$fail-fast, :$order, :$seed, :$show-seed)` | Per-suite summary: failures, counts, aborted line, seed announcement. The seed line is shown only when `$show-seed` is set or the run had failures. |
| `profile-summary(@records, :$limit)` | "Top N slowest" section when `--profile` is enabled. |
| `memory-profile-summary(@records, :$limit)` | "Top N memory-heaviest" section when `--memory-profile` is enabled. |
| `benchmark-summary-section(@summaries, @regressions, :$threshold, :$format, :$output, :$runner)` | Per-suite benchmark section when `--benchmark` is enabled. |
| `multi-file-overall($result, :$order, :$seed, :$show-seed)` | The `Overall:` block printed when running more than one spec file. Same seed-line gating as `run-summary`. |
| `multi-file-profile`, `multi-file-memory-profile`, `multi-file-benchmark` | Multi-file counterparts of the per-suite summary hooks. |
| `load-errors(@errors)` | Reports spec files that failed to compile. |

## Writing a custom formatter

```raku
use BDD::Behave::Formatter;
use BDD::Behave::Formatter::Registry;

class DotsFormatter does BDD::Behave::Formatter {
  method name(--> Str) { 'dots' }

  method example-pass($example)                   { print '.' }
  method example-fail($example, :$failure-info)   { print 'F' }
  method example-pending($example)                { print '*' }
  method example-skipped($example)                { print 'S' }
  method run-summary($result, *%) {
    say "";
    say "{$result.total} examples, {$result.failed} failed, {$result.passed} passed";
  }
}

BDD::Behave::Formatter::Registry.register('dots', DotsFormatter);
```

Once registered, the formatter is available to `--format`:

```shell
$ behave --format dots
```

## The registry

`BDD::Behave::Formatter::Registry` is a name-to-class lookup the CLI consults when resolving `--format`.

```raku
use BDD::Behave::Formatter::Registry;

BDD::Behave::Formatter::Registry.names;
# → (documentation html json json-events junit progress tap tree)

BDD::Behave::Formatter::Registry.register('dots', DotsFormatter);
BDD::Behave::Formatter::Registry.registered('dots');   # True
BDD::Behave::Formatter::Registry.lookup('dots');       # DotsFormatter
BDD::Behave::Formatter::Registry.create('dots');       # DotsFormatter instance

BDD::Behave::Formatter::Registry.reset;                # back to the built-ins
```

Duplicate registrations and classes that do not compose the role are rejected with a clear error.

## Passing a formatter directly to the runner

The runner accepts a `:formatter` argument for embedded use cases (custom CLIs, IDE integrations, etc.):

```raku
use BDD::Behave::Runner;
use BDD::Behave::Formatter::Tree;

my $f = BDD::Behave::Formatter::Tree.new;
my $runner = BDD::Behave::Runner::Runner.new(:formatter($f));
$runner.run($suite);
```

When `:formatter` is omitted, a `BDD::Behave::Formatter::Tree` instance is constructed automatically. (Note that the `behave` CLI selects `progress` by default when `--format` is not supplied. The runner constructor's default is `Tree` because tree output is the most useful for embedded/IDE consumers programmatically inspecting events.)
