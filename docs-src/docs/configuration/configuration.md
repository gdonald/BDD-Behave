# Configuration

Behave loads two Raku-based configuration files at startup and merges them with your CLI flags. This is the standard way to keep team-wide and machine-wide defaults out of every spec invocation.

## File format

A `.behave` file is a Raku script. It calls `configure-behave` with a block that receives a `Configuration` object:

```raku
use BDD::Behave::Configuration;

configure-behave -> $config {
  $config.format = 'documentation';
  $config.order  = 'random';
  $config.seed   = 12345;

  $config.include-tag('focus');
  $config.exclude-tag('slow');

  $config.aggregate-failures = True;
  $config.fail-fast          = 1;
}
```

Because the file is plain Raku, you can pull in helpers (`use ...;`) and compute values, but each `configure-behave` block should be self-contained: anything you set inside the block is stored on `$config` for the run.

## Precedence

When more than one source sets the same option, the highest-precedence source wins:

1. **CLI flags** (highest): explicit `--format`, `--order`, `--tag`, etc.
2. **Project config**: `.behave` in the current working directory.
3. **User config**: `~/.behave` in the user's home directory.
4. **Built-in defaults** (lowest): what Behave uses when nothing else is set.

List-style options (`include-tag`, `exclude-tag`, `example-pattern`, `only-location`, `spec-paths`, `include`, hooks) **accumulate** across all four layers: a tag listed in `~/.behave` and another listed on the CLI both apply. Scalar options like `format`, `order`, `seed`, `fail-fast`, `verbose`, and `aggregate-failures` **override**: the highest-precedence layer that sets them wins.

## Disabling configuration

Three CLI flags and one environment variable bypass config loading:

| Flag / env | Effect |
| ---------- | ------ |
| `--config PATH` | Load `PATH` as the only config, skipping `~/.behave` and `./.behave`. |
| `--no-config` | Skip both default config files entirely. |
| `--no-user-config` | Skip `~/.behave`, but still read `./.behave`. |
| `--no-project-config` | Skip `./.behave`, but still read `~/.behave`. |
| `BEHAVE_DISABLE_CONFIG=1` | Same as `--no-config`. Useful for CI and subprocess testing. |

`--config PATH` errors with exit code 2 if `PATH` does not exist.

## Settings

Every scalar attribute corresponds to its CLI counterpart:

| Configuration attribute | CLI flag | Notes |
| ----------------------- | -------- | ----- |
| `$config.format`               | `--format`         | A registered formatter name (e.g. `'progress'`). |
| `$config.order`                | `--order`          | `'random'` or `'defined'`. |
| `$config.seed`                 | `--seed`           | Int, only meaningful for `'random'`. |
| `$config.fail-fast`            | `--fail-fast[=N]`  | 0 disables, N >= 1 stops after N failures. |
| `$config.verbose`              | `--verbose`        | Bool. |
| `$config.aggregate-failures`   | `--aggregate-failures[=LABEL]` | Bool or Str label. |
| `$config.profile-limit`        | `--profile[=N]`    | 0 disables, N shows top-N slow examples. |
| `$config.slow-threshold`       | `--slow-threshold` | Real seconds. |
| `$config.benchmark-mode`       | `--benchmark`      | Bool. |
| `$config.benchmark-iterations` | `--benchmark-iterations` | Positive Int. |
| `$config.benchmark-baseline`   | `--benchmark-baseline` | `IO::Path`. |
| `$config.benchmark-save`       | `--benchmark-save` | `IO::Path`. |
| `$config.benchmark-threshold`  | `--benchmark-threshold` | Real fraction (0.10 = 10%). |
| `$config.benchmark-format`     | `--benchmark-format` | `'text'` or `'json'`. |
| `$config.benchmark-output`     | `--benchmark-output` | `IO::Path`. |
| `$config.parallel`             | `--parallel N`     | Int >= 1 enables parallel execution with N worker subprocesses. Absence (or value 0) keeps single-process serial execution. CLI overrides config. |
| `$config.parallel-mode`        | `--parallel-mode`  | `'isolated'` (default), `'lpt'`, or `'queue'`. See [Parallel Execution](../parallel/parallel.md#parallel-mode-parallel-mode). |
| `$config.parallel-retry`       | `--parallel-retry` | Non-negative Int. Per-shard retry budget when a worker crashes (exit > 1). See [Per-shard retry](../parallel/parallel.md#per-shard-retry-on-worker-crash-parallel-retry). |
| `$config.seed-mode`            | `--seed-mode`      | `'xor'` (default) or `'stable'`. |
| `$config.show-seed`            | `--show-seed`      | Bool. Print the seed even on a passing run (default prints it only on failure). |
| `$config.progress-total`       | `--progress-total` | Bool. Append a `(N/TOTAL)` counter to each progress char under `--parallel`. |

The list-style mutators are repeatable:

```raku
configure-behave -> $config {
  $config.include-tag('focus', 'wip');
  $config.exclude-tag('slow');
  $config.example-pattern('checkout flow');
  $config.only-location('specs/users-spec.raku:42');
  $config.include-spec('specs/');
}
```

`include-spec` populates the default list of spec paths used when no paths are passed on the CLI.

## Helper inclusion

`$config.include(SomeClass)` instantiates `SomeClass` once for the run and exposes it inside every example via the `$*BEHAVE-HELPERS` dynamic variable, keyed by the class's short name:

```raku
class APIHelpers {
  method as-user($name) { ... }
  method json-post(...) { ... }
}

configure-behave -> $config {
  $config.include(APIHelpers);
}
```

Inside a spec:

```raku
it 'creates a new order', {
  my $resp = $*BEHAVE-HELPERS<APIHelpers>.as-user('alice');
  expect($resp.status).to.eq(201);
}
```

Use `:as<key>` to choose a custom key, which is helpful when class names clash or you want a shorter accessor:

```raku
$config.include(APIHelpers, :as<api>);
# $*BEHAVE-HELPERS<api>.as-user('alice')
```

One instance is created per class per run (cached in the runner). State stored on a helper persists across all examples in the suite, so use it for fixtures and shared connections, not per-example state.

## Global hooks

Per-run hooks let you set up shared infrastructure without repeating it in every spec. Each phase composes with the per-group hooks declared inside spec files:

| Phase           | Fires |
| --------------- | ----- |
| `before-all`    | Once per suite, before any example runs. |
| `after-all`     | Once per suite, after every example has run. |
| `before-each`   | Before every example, before any group `before-each`. |
| `after-each`    | After every example, after any group `after-each`. |
| `around-each`   | Wraps every example, outside the group `around-each`. |

```raku
configure-behave -> $config {
  $config.before-all({ DB.migrate });
  $config.after-all({ DB.disconnect });

  $config.before-each({ DB.start-transaction });
  $config.after-each({ DB.rollback });

  $config.around-each(-> &next {
    my $start = now;
    next();
    note "example took {now - $start}s";
  });
}
```

Per-example phases (`before-each`, `after-each`, `around-each`) accept tag filters via named arguments:

```raku
$config.before-each({ Browser.launch }, :tag<feature>);
$config.after-each({  Browser.close  }, :tag<feature>);
```

Any unrecognised named argument is treated as a metadata filter: the hook only fires for examples whose effective metadata matches.

A global hook that throws is caught and reported as a warning so the run can continue.

## Metadata filtering

`$config.filter(:key<value>)` keeps only the examples whose effective metadata (declared via `:key<value>` on `describe`, `context`, or `it` and inherited down the tree) matches. Pass a `Bool` true value (`$config.filter(:db)`) to require the key to be present and truthy.

```raku
configure-behave -> $config {
  $config.filter(:type<unit>);     # only :type<unit> examples
  $config.filter(:db);             # only examples with :db
  $config.exclude-filter(:flaky);  # skip every :flaky example
}
```

Multiple `filter` calls combine with `AND`: each pair must match. `exclude-filter` does the opposite: any matching pair drops the example. Config-level filters also AND with `--tag`/`--exclude-tag`/`--example` on the CLI, and with focus mode.

## `filter-run-when-matching`

Inspired by RSpec's `config.filter_run_when_matching :focus`, this is a "soft" filter: it applies when at least one example matches, and is silently dropped otherwise so the rest of the run proceeds normally. Useful for a `focus` workflow: when you mark an example `:focus`, only it runs. When you remove the mark, the whole suite runs.

```raku
configure-behave -> $config {
  $config.filter-run-when-matching(:focus);
  $config.filter-run-when-matching(:wip);   # additional filter (AND with focus)
}
```

You can pass either a string key (treated as "metadata is truthy") or a pair (`key => value`). Multiple registrations stack with `AND` semantics, but each one is independently checked for the no-match short-circuit: a registration that matches nothing is dropped without affecting the others.

`filter-run-when-matching` interacts with the other filters:

| Other filter active | Behavior |
| ------------------- | -------- |
| None | The filter applies if any example matches. Otherwise the entire suite runs. |
| `--tag`, `--exclude-tag`, `--example` | The filter is checked against the full spec tree. If it matches, it is added to the AND set with the CLI filters. |
| `$config.filter` (hard) | Hard filter applies first. If `filter-run-when-matching` matches under that constraint, both apply. |

## Example: complete `.behave`

```raku
use BDD::Behave::Configuration;

class APIHelpers {
  method as-user($name) { ... }
}

configure-behave -> $config {
  # Defaults
  $config.format        = 'documentation';
  $config.order         = 'random';
  $config.fail-fast     = 1;
  $config.profile-limit = 10;

  # Default spec paths (used when none are passed on the CLI)
  $config.include-spec('specs/');

  # Helpers
  $config.include(APIHelpers);

  # Global setup / teardown
  $config.before-all({ DB.migrate });
  $config.after-all({  DB.disconnect });

  # Filters
  $config.exclude-filter(:flaky);

  # Honor a :focus marker when present
  $config.filter-run-when-matching(:focus);
}
```

With this file in your project root, `behave` (no arguments) loads it, applies your CLI flags on top, and runs `specs/` in documentation format with full focus / flaky / DB management, no flags required.
