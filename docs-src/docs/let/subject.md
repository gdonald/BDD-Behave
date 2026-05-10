# subject

`subject` defines the primary value under test in a `describe` or `context` block. It is implemented as a [`let`](let.md) under the name `:subject`, so all of `let`'s lazy-and-memoized semantics apply.

Use `subject` when you want to name "the thing this group is about" once and refer to it across many examples.

## Defining a subject

Three forms are accepted:

```raku
subject({ Widget.new(:bar(99)) });          # anonymous, registered as :subject
subject(:widget, { Widget.new(:bar(99)) }); # named, also aliased as :subject
subject('widget', { Widget.new(:bar(99)) }); # string-name form, also aliased as :subject
```

When a name is given, the value is reachable through both the given name and `:subject` — they share a single memoized evaluation per example.

## Reading the subject

There are three ways to read the subject:

### 1. The `subject()` reader

Inside an example, calling `subject()` with no arguments returns the memoized value:

```raku
describe 'Widget', {
  subject({ Widget.new(:bar(99)) });

  it 'has the right bar', {
    expect(subject().bar).to.be(99);
  }
}
```

`subject()` outside an example body raises an error.

### 2. Named-argument form in `expect`

```raku
describe 'Widget', {
  subject({ Widget.new(:bar(99)) });

  it 'is a Widget', {
    expect(:subject).to.be(Widget);
  }
}
```

### 3. Through the given name when `subject(:name, ...)` is used

```raku
describe 'Widget', {
  subject(:widget, { Widget.new(:bar(99)) });

  it 'is reachable as :widget', {
    expect(:widget).to.be(Widget);
  }

  it 'and as :subject', {
    expect(:subject).to.be(Widget);
  }
}
```

## Memoization

`subject` is **lazy**: the block runs the first time it's read in an example, and the value is cached for subsequent reads in the same example. Between examples the cache is reset.

```raku
my $hits = 0;
describe 'memo', {
  subject({ ++$hits });

  it 'evaluates once', {
    subject(); subject(); subject();
    expect($hits).to.be(1);
  }
}
```

## Shadowing

Inner `subject` definitions shadow outer ones for examples in the inner group:

```raku
describe 'outer', {
  subject({ 'outer' });

  it 'sees outer', { expect(:subject).to.be('outer') }

  context 'inner', {
    subject({ 'inner' });

    it 'sees inner', { expect(:subject).to.be('inner') }
  }
}
```

## `subject-bang` (eager evaluation)

`subject-bang` is the Raku-friendly spelling of RSpec's `subject!`. It defines a subject like `subject` does, but the block is **forced before every example body** so any side effects in the block run whether or not the example reads the value.

```raku
describe 'invoices index', {
  subject-bang(:invoice, { Invoice.create(:amount(100)) });

  it 'returns invoices', {
    expect(Invoice.all.elems).to.be(1);   # passes even though we never read :invoice
  }
}
```

`subject-bang` accepts the same three forms as `subject`:

```raku
subject-bang({ User.create });
subject-bang(:user,  { User.create });
subject-bang('user', { User.create });
```

It registers the let definition(s) and a `before-each` hook in the current group that forces `:subject`. Memoization is the same as `subject` — the block runs at most once per example.

### When to use `subject-bang`

Use `subject-bang` when the *creation* of the subject is itself the test setup — typically for inserting database rows or otherwise mutating state that the example depends on existing before it runs. For pure values, plain `subject` is preferred because it stays cheap when the example doesn't actually read the value.

### Restrictions

- `subject-bang` must be called inside a `describe` or `context`. At the top-level (suite scope), only plain `subject` is supported.
- Inside an `it` block, use `subject()` or `expect(:subject)` to read the value; eager forcing is meaningless once you're already in the example body.

## Comparison with `let`

`subject` is sugar around `let(:subject, ...)`. The two are interchangeable when reading via `:subject`, but `subject` makes the intent — "this is what I'm testing" — explicit and adds the dual-name alias when you give it a name. Use `subject` for the value under test and `let` for everything else (inputs, fixtures, helpers).
