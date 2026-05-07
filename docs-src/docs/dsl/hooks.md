# Hooks

Hooks let you run setup and teardown code around examples. Behave provides four hooks:

| Hook | Fires |
| --- | --- |
| `before-all`  | Once, before the first example in the group |
| `before-each` | Before every example in the group (and inherited by nested groups) |
| `after-each`  | After every example in the group (and inherited by nested groups) |
| `after-all`   | Once, after the last example in the group |

All four are exported from `BDD::Behave` and must be called inside a `describe` or `context` block.

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

## Metadata-keyed hooks

All four hooks accept metadata filters that gate when the hook fires. Filters
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
