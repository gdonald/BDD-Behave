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
