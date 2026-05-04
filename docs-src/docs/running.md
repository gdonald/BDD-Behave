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

| Option | Effect |
| --- | --- |
| `--help` | Display usage |
| `--verbose` | Print each spec file as it is loaded |

## Output

Behave prints each describe/context with a `⮑` marker, indenting nested groups, and reports `SUCCESS` / `FAILURE` / `PENDING` per example. After all suites run it prints a summary like:

```
============================================================
Overall: 96 examples
  96 passed
```

## Exit code

`behave` exits `0` if every example passed, `1` if any example failed.
