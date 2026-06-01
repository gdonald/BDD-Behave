# Variables in specs

Because Behave specs are plain Raku, `my` and `our` variables work exactly as you'd expect. You don't need a special DSL to declare state, though [`let`](../let/let.md) is usually the right tool when you want **per-example** memoization with automatic reset.

## Top-level variables

Declared at the top of the spec file, visible to every `describe` and `it`:

```raku
use BDD::Behave;

my $top      = 'top-level';
my @numbers  = (1, 2, 3);
my %settings = (timeout => 5);

describe 'top-level access', {
  it 'reads scalars, arrays, hashes', {
    expect($top).to.be('top-level');
    expect(@numbers[2]).to.be(3);
    expect(%settings<timeout>).to.be(5);
  }
}
```

## Variables inside `describe` / `context`

A `my` declared inside a `describe` is shared across that group's examples. Mutations carry over between examples in registration order:

```raku
describe 'shared describe-level state', {
  my $counter = 0;

  it 'a', { expect(++$counter).to.be(1); }
  it 'b', { expect(++$counter).to.be(2); }
  it 'c', { expect(++$counter).to.be(3); }
}
```

This is the **opposite** of [`let`](../let/let.md), which resets between examples. Reach for `let` when you want isolation. Use a plain `my` when you intentionally want shared state.

## Shadowing in nested contexts

Inner `my` declarations shadow outer ones the same way they would in any Raku block:

```raku
describe 'shadowing', {
  my $value = 'outer';

  it 'sees outer', { expect($value).to.be('outer') }

  context 'inner', {
    my $value = 'inner';
    it 'sees inner', { expect($value).to.be('inner') }
  }

  it 'outer unchanged after nested context', {
    expect($value).to.be('outer');
  }
}
```

## Variables inside `it`

Variables declared inside an `it` block are example-local and never leak:

```raku
describe 'it-local vars', {
  it 'first',  { my $x = 'first';  expect($x).to.be('first') }
  it 'second', { my $x = 'second'; expect($x).to.be('second') }
}
```

## When to use `let` vs a plain variable

| Use a plain `my` | Use [`let`](../let/let.md) |
| --- | --- |
| Shared mutable state across examples | Fresh value per example |
| Cheap constants | Expensive setup that should run lazily |
| Counters, accumulators | Test subjects, fixtures |

`let` works alongside plain variables: you can mix both in the same describe.

## Classes, roles, enums

Type declarations follow the same scoping rules. See [Classes inside specs](../classes/classes.md).
