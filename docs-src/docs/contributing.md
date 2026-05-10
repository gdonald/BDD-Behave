# Contributing to Behave

This guide covers what you need to know to hack on Behave itself. If you're just *using* Behave for your own project, the [Getting Started](getting-started.md) and [Running Specs](running.md) pages are what you want.

## Test surfaces

Behave has two test surfaces, and a change is not considered done until **both** pass:

1. **Specs in `specs/`** — Behave's own behavioral test suite, written with the `behave` DSL and run by the `behave` runner. New features should land with specs that demonstrate the user-facing behavior.
2. **Unit tests in `t/`** — `Test`-module tests that exercise individual classes (Runner, SpecTree, DSL helpers, etc.), run with `prove6`. Use these for tight, focused checks of internal invariants.

The two layers mirror each other folder-for-folder: every spec at `specs/X/Y-spec.raku` has a counterpart at `t/X/Y.rakutest`. Adding a new spec? Add the matching unit test in `t/`. Adding a new unit test? Add the matching spec.

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
$ raku -Ilib t/hooks/hooks.rakutest
```

## Both at once

When developing Behave itself, run both before considering a change done:

```shell
$ prove6 -Ilib t && raku -Ilib bin/behave
```

## Coverage expectations

100% test coverage is the bar for new code. Both surfaces must cover the change:

- A new DSL function or runner option needs a spec demonstrating the user-facing behavior **and** unit tests pinning down the implementation details.
- A bug fix needs a regression spec **and** the matching unit test that would have caught the bug.

## Documentation

Documentation lives in `docs-src/`:

- Per-feature pages live under `docs-src/docs/<topic>/<topic>.md`, mirroring the `specs/` folder layout.
- After modifying anything under `docs-src/`, run `docs-src/build.sh` to regenerate the published HTML in `docs/`. The build step is local; CI does not regenerate docs.

## Continuous integration

Pushes and pull requests run the full suite via the [GitHub Actions workflow](https://github.com/gdonald/BDD-Behave/blob/main/.github/workflows/ci.yml). The same workflow publishes this documentation site to GitHub Pages on every push to `main`, serving the committed `docs/` directory.
