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
