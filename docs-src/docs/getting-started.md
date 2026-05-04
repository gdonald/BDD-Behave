# Getting Started

## Project layout

A Behave project keeps spec files in a `specs/` directory at the project root. The `behave` runner picks up any file matching `spec.raku` (e.g. `001-basic-spec.raku`, `users-spec.raku`, `subdir/admin-spec.raku`).

```
my-project/
├── lib/
│   └── MyApp.rakumod
└── specs/
    ├── basic-spec.raku
    └── users/
        └── auth-spec.raku
```

## Your first spec

Every spec file starts with `use BDD::Behave;` and then declares one or more top-level `describe` blocks.

```raku
use BDD::Behave;

describe 'arithmetic', {
  it 'adds integers', {
    expect(1 + 1).to.be(2);
  }

  it 'multiplies integers', {
    expect(3 * 4).to.be(12);
  }
}
```

## Running specs

Run all specs found in `specs/`:

```shell
behave
```

Run a single spec file:

```shell
behave specs/basic-spec.raku
```

During local development of an app whose `lib/` is not yet installed, prefix with `raku -Ilib`:

```shell
raku -Ilib bin/behave specs/basic-spec.raku
```

See [Running Specs](running.md) for the full set of options.

## Where to go next

- [`describe` / `context`](dsl/describe.md) — group related examples
- [`it`](dsl/it.md) — define an example
- [`let`](dsl/let.md) — lazy, memoized values per example
- [Hooks](dsl/hooks.md) — `before-each`, `after-each`, `before-all`, `after-all`
- [`expect`](dsl/expect.md) — assertions
