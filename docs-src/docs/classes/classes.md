# Classes inside specs

Behave specs are ordinary Raku files, so any Raku declaration works inside them, including `class`, `role`, and `enum`. Declare fixture types with `my class` / `my role` / `my enum` so they stay lexical to the spec file: they don't pollute the loader's package, they don't collide with same-named declarations in other specs, and their `.^name` reads as the short name you wrote.

## Declaring a class in a describe

```raku
use BDD::Behave;

describe 'Widget', {
  my class Widget {
    has $.bar;
    has $.baz;

    submethod BUILD(:$!bar) {
      $!baz = 42;
    }
  }

  it 'sets attributes', {
    my $w = Widget.new(:bar(17));
    expect($w.bar).to.be(17);
    expect($w.baz).to.be(42);
  }
}
```

The class lives in the lexical scope of the describe body, so it is visible to nested `context` blocks and every `it` inside them.

## Storing instances with `let`

For values you want freshly built per example with optional memoization, combine `my class` with [`let`](../let/let.md):

```raku
describe 'Widget', {
  my class Widget {
    has $.bar;
  }

  let(:widget, { Widget.new(:bar(99)) });

  it 'reads via the context parameter', -> $_ {
    expect(.widget.bar).to.be(99);
  }

  it 'reads via the bareword', {
    expect(widget.bar).to.be(99);
  }
}
```

Each example gets its own memoized instance: the let block runs once per example, never carries over.

## Roles and enums

Roles and enums work the same way:

```raku
describe 'Greet role', {
  my role Greet { method hi { 'hi' } }
  my class WithGreet does Greet { }

  it 'composes', {
    expect(WithGreet.new.hi).to.be('hi');
  }
}

describe 'Color enum', {
  my enum Color <Red Green Blue>;

  it 'has correct ordinals', {
    expect(Red.Int).to.be(0);
    expect(Blue.Int).to.be(2);
  }
}
```

## Top-level vs in-block

Classes can also be declared at the top of the spec file, before any `describe`. Pick whichever scope is narrowest for the class's intended use:

- **Top-level** when several `describe` blocks share the type.
- **Inside `describe`** when the type is only meaningful for one group of examples. Keeping it local makes the relationship between the type and the tests obvious.

In both positions, use `my class` (not `class`) for the same reasons given above. File-scope `class Foo { }` is sugar for `our class Foo { }` and installs `Foo` into the spec loader's package, where it can collide with other specs and grow a package-qualified `.^name`.

See [Variables in specs](../variables/variables.md) for the same scoping rules applied to plain `my`/`our` variables.
