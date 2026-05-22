# Retry and only-failures

Flaky examples — those that fail intermittently because of timing, network jitter, ordering of external services, or other non-determinism — can be retried automatically. Behave also persists the list of failing examples after every run so you can re-run just those failures next time.

## `--retry N`

`--retry N` runs each failing example up to `N` additional times. A total of `N+1` attempts will be made. The first attempt that passes wins; the example is marked passing in the final summary. If every attempt fails, the example is marked failing and the final attempt's failures are the ones reported.

```shell
$ behave --retry 2
```

This is the simplest form: every failing example in the run gets up to two retries.

### Per-example `:retry(N)`

Override the runner default for a single example or group with `:retry(N)` metadata. The DSL forwards arbitrary metadata onto the example, and the runner looks up `retry` through the usual `effective-metadata-value` walk (so group-level `:retry(N)` cascades to descendants).

```raku
describe 'flaky API tests', :retry(2), {
  it 'fetches the timeline', {
    expect(api.timeline).to.include('latest');
  }

  it 'pings once with an aggressive timeout', :retry(5), {
    expect(api.ping(:timeout(0.1))).to.be-truthy;
  }

  it 'never retries this one', :retry(0), {
    # Even with --retry 5, this example runs at most once.
  }
}
```

`:retry(N)` on a single example overrides any inherited value, including `--retry` from the command line. `:retry(0)` is the explicit way to disable retries for an example that would otherwise inherit a higher value.

### What re-runs between attempts

A retry re-runs the example body and the example's `before-each` / `after-each` / `around-each` hooks. Group-level `before-all` / `after-all` and `around-all` run once per group as usual — they are not re-executed on retry.

Other per-attempt state:

- **`let` memoization** is reset between attempts, so lazy `let { ... }` bodies re-evaluate.
- **Stubs installed via `allow(...)`** are cleaned up between attempts via the same `StubRegistry` snapshot-and-restore mechanism that wraps every example. Stubs installed in `before-all` survive across attempts.
- **`Failures.list`** is snapshotted at the start of each attempt. If the attempt fails and we are going to retry, the intermediate failures are spliced back out — they never make it into the final summary or into `.behave-failures`.

Pending (`pending` or `it 'todo'`) and skipped (`:skipped`, `xit`, `xdescribe`) examples are never retried.

### Output while retries happen

Between attempts the formatter emits a retry marker:

- **Progress formatter**: yellow `R` for each failed attempt.
- **Tree / documentation formatters**: a `RETRY (attempt N of M)` line.

After the run, if at least one retry actually happened, a summary section is printed:

```
Retried 2 examples:
  [PASS] flaky API tests fetches the timeline (2/3 attempts)
         /Users/me/repo/specs/api-spec.raku:8
  [FAIL] flaky API tests pings once with an aggressive timeout (6/6 attempts)
         /Users/me/repo/specs/api-spec.raku:12
```

`[PASS]` means the example eventually succeeded after `N` retries; `[FAIL]` means every attempt failed. `N/M attempts` is the actual number of attempts used over the maximum allowed. When no retries occurred, the section is omitted entirely.

### Programmatic use

`BDD::Behave::Runner::Runner.new` accepts `:retry(N)` (default `0`, meaning no retries). After the run, `$runner.result.retry-records` is a list of `BDD::Behave::Runner::RetryRecord` objects, each with `description`, `location`, `attempts`, `max-attempts`, and `outcome` (the string `'pass'` or `'fail'`):

```raku
my $runner = BDD::Behave::Runner::Runner.new(:retry(3));
$runner.run($suite);
for $runner.result.retry-records -> $rec {
  say "{$rec.outcome.uc} {$rec.description} ({$rec.attempts}/{$rec.max-attempts})";
}
```

`Runner.new(:retry(-1))` (or any negative integer) dies at construction time.

## `--only-failures`

`--only-failures` re-runs only the examples that failed in the previous run. After every non-bisect run, Behave writes a list of failing locations to `./.behave-failures` (one `FILE:LINE` per line). On the next invocation, `--only-failures` reads that file and treats each entry as if it were passed via `--only-example`.

```shell
$ behave                  # full run; some examples fail
$ behave --only-failures  # rerun just the failures
```

When `--only-failures` is set but the file is missing or contains no entries, every example runs (with a notice on stderr).

`--only-failures` combines with `--tag`, `--exclude-tag`, `--example`, `--retry`, and the other filters using the existing AND semantics. A common workflow is `behave --only-failures --retry 2` to give every previously-failing example two extra chances after a fix attempt.

### How the file is updated

After every run, Behave merges the new failure list with the existing file:

- Examples that ran in this run and now pass are removed.
- Examples that ran and still fail are kept (or added).
- Examples that did NOT run this time (filtered out, in a spec file you did not select, etc.) are preserved as-is.

A filtered run like `behave specs/auth-spec.raku --only-failures` will only update entries belonging to `auth-spec.raku`; failing entries for other spec files stay in the list until you re-run them.

### `--failures-path PATH`

Override the default path with `--failures-path PATH` (or `--failures-path=PATH`). Useful when running concurrent suites that should not share a failures list, or when persisting failures somewhere outside the working directory:

```shell
$ behave --failures-path /tmp/behave-failures-feature-x.txt
$ behave --only-failures --failures-path /tmp/behave-failures-feature-x.txt
```

### Modes that do not write `.behave-failures`

`--bisect` and `--bisect-data` use their own machine-readable output protocol and do not write the failures file. All other modes — including `--parallel`, `--coverage`, and `--doc` — write the file at the end of the run.

`.behave-failures` is plain text (one location per line, blank lines and `#` comments ignored on read) so it is safe to edit by hand or to consume from other tooling.
