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
