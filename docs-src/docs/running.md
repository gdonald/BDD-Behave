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
| `--tag NAME`         | Run only examples tagged `NAME` (repeatable; OR semantics). See [Tags](dsl/tags.md).                                    |
| `--exclude-tag NAME` | Skip examples tagged `NAME` (repeatable).                                                                               |
| `--example PATTERN`  | Run only examples whose full nested description matches `PATTERN` (substring; or `/regex/`). Repeatable; OR semantics.  |
| `-e PATTERN`         | Alias for `--example`.                                                                                                  |

## Filtering examples by description

`--example PATTERN` (alias `-e PATTERN`) runs only examples whose full nested description matches `PATTERN`. The full nested description joins every enclosing `describe` / `context` description with the `it` description, separated by spaces:

```raku
describe 'User signup', {
  context 'with a referral code', {
    it 'awards bonus credits', { ... }    # full description: "User signup with a referral code awards bonus credits"
  }
}
```

By default `PATTERN` is a substring:

```shell
$ behave --example 'User signup'           # every example under User signup
$ behave -e 'awards bonus'                 # the single example
```

Wrap `PATTERN` in `/.../` to use a Raku regex. Standard regex rules apply, so use `\s` (or quote literal text) for whitespace:

```shell
$ behave --example '/\d+/'                 # every example whose description has a digit
$ behave --example '/User\s+signup/'       # User-signup-related examples via regex
```

Repeat the flag for OR semantics:

```shell
$ behave --example 'User signup' --example 'Order checkout'
```

`--example` combines with `--tag`, `--exclude-tag`, and focused/skipped examples using AND semantics — an example must satisfy every active filter to run. Groups whose subtrees contain no matching examples are skipped, including their `before-all` / `after-all` / `around-all` hooks.

## Output

Behave prints each describe/context with a `⮑` marker, indenting nested groups, and reports `SUCCESS` / `FAILURE` / `PENDING` / `SKIPPED` per example. See [Focus and Skip](dsl/focus-skip.md) for `xit` / `fit` / `xdescribe` / `fdescribe`. After all specs run it prints a summary like:

```
============================================================
Overall: 96 examples
  96 passed
```

## Exit code

`behave` exits `0` if every example passed, `1` if any example failed.
