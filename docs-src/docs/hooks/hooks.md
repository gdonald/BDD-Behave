# Hooks

Hooks let you run setup and teardown code around examples. Behave provides six hooks:

| Hook | Fires |
| --- | --- |
| `before-all`  | Once, before the first example in the group |
| `before-each` | Before every example in the group (and inherited by nested groups) |
| `after-each`  | After every example in the group (and inherited by nested groups) |
| `after-all`   | Once, after the last example in the group |
| `around-each` | Wraps each example *and* its `before-each` / `after-each` hooks |
| `around-all`  | Wraps the entire group, including `before-all` / `after-all` |

All six are exported from `BDD::Behave` and must be called inside a `describe` or `context` block.

## Basic example

```raku
describe 'a counter', {
  my $count;

  before-each {
    $count = 0;
  }

  it 'starts at zero', {
    expect($count).to.be(0);
  }

  it 'is reset between examples', {
    $count++;
    expect($count).to.be(1);
  }
}
```

## Ordering and inheritance

Within a group, hooks run in registration order. When examples live in nested groups, outer `before-each` hooks fire **outer-to-inner**, and outer `after-each` hooks fire **inner-to-outer**:

```raku
describe 'outer', {
  before-each { trace('outer-before') }
  after-each  { trace('outer-after')  }

  context 'inner', {
    before-each { trace('inner-before') }
    after-each  { trace('inner-after')  }

    it 'runs', {
      # trace so far: outer-before, inner-before
      trace('example');
    }
    # after the example: inner-after, outer-after
  }
}
```

## `before-all` / `after-all`

These fire exactly once per group — useful for expensive shared setup.

```raku
describe 'database queries', {
  before-all {
    setup-fixture-data;
  }

  after-all {
    teardown-fixture-data;
  }

  it 'finds a user', { ... }
  it 'finds a page', { ... }
}
```

!!! warning
    Anything `before-all` mutates is shared across the group's examples. Prefer `before-each` for per-example isolation.

## `around-each` and `around-all`

Around hooks receive a continuation — a `Callable` that runs everything inside
the wrapper. The hook is responsible for invoking it. This makes around hooks
the right tool for *paired* setup/teardown that must bracket the example, even
across exceptions.

`around-each` wraps each example, including its `before-each` and `after-each`
hooks:

```raku
describe 'users repository', {
  around-each -> &continue {
    begin-transaction;
    LEAVE rollback-transaction;
    continue();
  }

  it 'creates a user', { ... }
  it 'finds a user',   { ... }
}
```

`around-all` wraps the entire group, including `before-all` and `after-all`:

```raku
describe 'expensive integration suite', {
  around-all -> &continue {
    boot-fixture-server;
    LEAVE shutdown-fixture-server;
    continue();
  }

  before-all { ... }   # runs *inside* the around-all wrapper
  it 'a',     { ... }
  it 'b',     { ... }
}
```

Either form of around hook can also be written as a bare block that uses the
implicit `$_`:

```raku
around-each {
  setup-context;
  $_();
  teardown-context;
}
```

### Composition order

When a single group registers multiple around hooks, the **first-registered
hook is outermost** — the second is wrapped by the first, and so on. Across
nested groups, outer-group around hooks wrap inner-group around hooks:

```raku
describe 'outer', {
  around-each -> &c { trace('outer-start'); c(); trace('outer-end') }

  context 'inner', {
    around-each -> &c { trace('inner-start'); c(); trace('inner-end') }

    it 'runs', { trace('body') }
    # trace: outer-start, inner-start, body, inner-end, outer-end
  }
}
```

### Skipping the continuation

If an around hook returns without invoking the continuation, the example (or
group) is reported as **skipped** and counted in the suite's `skipped` total.
This lets you write conditional skips inline:

```raku
around-each -> &continue {
  unless $env-supports-feature {
    return;   # example is recorded as skipped
  }
  continue();
}
```

### Exceptions

If an around hook throws **before** invoking the continuation, the example is
recorded as a failure and the exception is captured. If a hook throws
**after** the continuation completes, Behave prints a warning but does not
overwrite the example's already-recorded result.

Exceptions raised inside the example body are still handled by Behave's
existing `expect` / `Failures` machinery and *do not* propagate up through the
continuation — wrap the example body with the relevant matcher instead.

### Metadata filters

Around hooks accept the same metadata filters as the other hook phases (see
below):

```raku
around-each :tag<db>, -> &continue {
  begin-transaction;
  LEAVE rollback-transaction;
  continue();
}
```

For `around-all`, the hook fires only when at least one descendant example
matches the filter — mirroring `before-all` / `after-all` filter semantics.

## Metadata-keyed hooks

All six hooks accept metadata filters that gate when the hook fires. Filters
are passed as named arguments before the block:

```raku
before-each :tag<database>, {
  setup-fixture;
}

after-each :tag<database>, {
  rollback-fixture;
}
```

The hook only fires for examples whose **effective tags or metadata** match the
filter. Effective metadata is collected by walking the ancestry from the
example up through every enclosing `describe`/`context`, so a tag on the outer
group is inherited by every example below it.

### Tag filters

| Filter | Meaning |
| --- | --- |
| `:tag<name>` | example must have this tag |
| `:tags<a b c>` | example must have **all** of these tags (AND) |
| `:exclude-tag<name>` | example must **not** have this tag |
| `:exclude-tags<a b>` | example must not have any of these tags |

### Arbitrary metadata

Any other named argument on `it` / `describe` / `context` becomes example
metadata, and any other named argument on a hook becomes a metadata filter:

```raku
describe 'user-service', :type<model>, {
  before-each :type<model>, {
    seed-models;
  }

  it 'finds a user', { ... }   # type<model> inherited; hook fires
}

context 'view layer', :type<view>, {
  before-each :type<view>, {
    setup-renderer;
  }

  it 'renders', { ... }
}
```

A filter value that is a list (e.g. `:role<admin staff>`) matches when the
example's stored metadata contains any of the listed values.

### AND semantics across keys

When a hook lists multiple filter keys, every key must match:

```raku
# Fires only when an example is tagged :db AND not tagged :read-only
before-each :tag<db>, :exclude-tag<read-only>, {
  begin-transaction;
}
```

To get OR-style behavior, register multiple hooks.

### `before-all` and `after-all` filters

Filters on `before-all` / `after-all` fire once per group, but only when at
least one descendant example matches. If a tag-filtered `before-all` has no
matching descendants — for example because all matching examples were excluded
by the runner's `--tag` filter — the hook is skipped entirely along with its
paired `after-all`.

```raku
describe 'database tests', {
  before-all :tag<expensive>, {
    seed-large-fixture;   # only when an :expensive example will run
  }

  after-all :tag<expensive>, {
    drop-large-fixture;
  }

  it 'cheap',     :tag<cheap>,     { ... }   # hook does not fire
  it 'expensive', :tag<expensive>, { ... }   # hook fires once for the group
}
```
