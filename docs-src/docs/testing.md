# Tests

Behave has two test surfaces:

1. **Specs in `specs/`** — Behave's own behavioral test suite, run with the `behave` runner.
2. **Unit tests in `t/`** — `Test`-module tests that exercise individual classes (Runner, SpecTree, DSL helpers, etc.), run with `prove6`.

## Running the specs

```shell
$ raku -Ilib bin/behave
```

This loads every `*spec.raku` file under `specs/` and runs them through the Behave runner.

## Running the unit tests

```shell
$ prove6 -Ilib t
```

You can also run a single test file directly:

```shell
$ raku -Ilib t/dsl/hooks.rakutest
```

## Both at once

When developing Behave itself, run both before considering a change done:

```shell
$ prove6 -Ilib t && raku -Ilib bin/behave
```

## Continuous integration

Pushes and pull requests run the full suite via the [GitHub Actions workflow](https://github.com/gdonald/BDD-Behave/blob/main/.github/workflows/raku.yml). The same workflow builds and publishes this documentation site to GitHub Pages on every push to `main`.
