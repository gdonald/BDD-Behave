# let

`let` defines a value that is **lazy** (only computed when first read) and **memoized per example** (reset between examples). Use it for the test subject and any inputs whose construction you'd otherwise repeat.

## Defining a let

Two equivalent forms:

```raku
let('answer', { 42 });   # string name
let(:answer,  { 42 });   # named-argument form
```

A `let` declared in a `describe` or `context` is visible to every example in that group and its nested groups.

## Reading a let

There are three ways to read a let value:

### 1. Named-argument form in `expect`

```raku
describe 'answer', {
  let(:answer, { 42 });

  it 'is 42', {
    expect(:answer).to.be(42);
  }
}
```

### 2. Binding syntax — `:=` to a normal variable

This is the most flexible form: bind once, then use the variable like any other.

```raku
describe 'widget', {
  it 'has the expected fields', {
    my $w := let(:widget, { Widget.new(:bar(99)) });

    expect($w.bar).to.be(99);
    expect($w.baz).to.be(42);
  }
}
```

### 3. Context-parameter form

If the example block takes a positional parameter, the context object exposes lets as methods:

```raku
let(:widget, { Widget.new(:bar(88)) });

it 'reads via the context parameter', -> $_ {
  expect(.widget.bar).to.be(88);
}
```

### 4. Bareword

A `let` name is also available as a bareword inside the group that defined it —
no sigil, no `expect` wrapper. This is the most direct form and works in any
position: method calls, arguments, and data structures.

```raku
describe 'pages', {
  let(:owner, { User.create(name => 'Alice') });

  it 'reads the bareword anywhere', {
    Page.create({user => owner, name => 'Home'});

    expect(User.find(owner.id).pages.elems).to.eq(1);
  }
}
```

Barewords also work for `let-bang` and `subject` names.

A `let` must be **defined before it is used**: a bareword referenced earlier in
the file than its `let` line will not compile. A bareword that was never
defined as a `let` is an ordinary undeclared-routine compile error, so typos
are caught at compile time.

## Fetch form

Calling `let` with a name and no block returns the value directly. Both name
spellings work — `let(:answer)` and `let('answer')` — and it can be used in any
position:

```raku
describe 'fetch form', {
  let(:user, { User.create(name => 'Alice') });

  it 'reads the value in any position', {
    Page.create({user => let(:user), name => 'Home'});

    expect(User.find(let(:user).id).pages.elems).to.eq(1);
  }
}
```

The fetch form shares the same memoization as the definition, must be called
while an example is running, and raises for an unknown name.

## Memoization

Within a single example, calling a let multiple times returns the same value:

```raku
let(:counter, { $n++ });   # called once per example

it 'memoizes within an example', {
  expect(:counter).to.be(:counter);   # same value both reads
}
```

Between examples the cache is reset, so each example sees a fresh value.

## Nested lets and shadowing

Inner `let` definitions shadow outer ones with the same name.

```raku
describe 'shadowing', {
  let(:value, { 'outer' });

  it 'sees outer', { expect(:value).to.be('outer') }

  context 'inside', {
    let(:value, { 'inner' });

    it 'sees inner', { expect(:value).to.be('inner') }
  }
}
```

Shadowing one `let` with another of the same name is normal and silent. But if
a `let` name shadows an existing non-let symbol in the same scope (a `sub` or
variable), a warning is printed at compile time so the collision is not silent.

## `let-bang` (eager evaluation)

`let-bang` is the Raku-friendly spelling of RSpec's `let!`. It defines the same kind of memoized value as `let`, but it is **forced before every example body** so any side effects in the block run whether or not the example reads the value.

`let-bang` is sugar for:

```raku
let(:user, { User.create });
before-each { let-runtime-force(:user) };   # conceptually
```

It registers the let definition and a `before-each` hook in the current group. The two forms accepted are the same as `let`:

```raku
let-bang('user', { User.create });
let-bang(:user,  { User.create });
```

### When to use `let-bang`

Use `let-bang` when the *creation* of a value is itself the test setup — typically for inserting database rows, recording fixtures, or otherwise mutating state that the example depends on existing before it runs. For pure values, plain `let` is preferred because it stays cheap when the example doesn't actually read the value.

```raku
describe 'invoices index', {
  let-bang(:invoice, { Invoice.create(:amount(100)) });

  it 'returns invoices', {
    expect(Invoice.all.elems).to.be(1);   # passes even though we never read :invoice
  }
}
```

### Memoization is the same as `let`

Within an example, the block runs at most once. Reads after the eager force return the cached value:

```raku
let-bang(:counter, { ++$n });

it 'is forced once per example', {
  expect(:counter).to.be(:counter);   # one increment, two reads
}
```

Between examples the cache is reset, so the block runs once per example.

### Ordering

`let-bang` registers a real `before-each` hook on the surrounding group, so it composes with `before-each` in **declaration order**:

```raku
describe 'order', {
  before-each   { say 'be1' };
  let-bang(:x,  { say 'eager' });
  before-each   { say 'be2' };

  it 'runs', { say 'body' };
}
# Output per example:
# be1
# eager
# be2
# body
```

Multiple `let-bang` declarations evaluate in the order they appear.

### Inheritance and shadowing

Outer `let-bang` definitions are inherited by inner `describe`/`context` blocks. If an inner group shadows the same name with another `let` (or `let-bang`), reads see the inner value, and the inner block is what gets forced:

```raku
describe 'outer', {
  let-bang(:value, { 'outer' });

  context 'inner', {
    let(:value, { 'inner' });

    it 'sees inner', {
      expect(:value).to.be('inner');   # outer block does not run
    }
  }
}
```

### Restrictions

- `let-bang` must be called inside a `describe` or `context`. At the top-level (suite scope) only plain `let` is supported.
- Inside an `it` block, use plain `let` with binding (`my $x := let(:name, { ... })`); eager forcing is meaningless once you're already in the example body.
