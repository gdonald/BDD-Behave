# Shared Examples

Shared examples let you package up a set of `it` blocks under a name and reuse them across any number of `describe` or `context` groups. They're useful when several types or implementations should satisfy the same behavior contract — a "counter," a "comparable," a "queue" — without copy-pasting the `it`s into every spec.

`shared-examples`, `include-examples`, and `it-behaves-like` are exported from `BDD::Behave`.

Shared examples are a complement to [Shared Contexts](shared-contexts.md): a shared *context* contributes setup (lets and hooks); shared *examples* contribute the assertions themselves.

## Defining shared examples

`shared-examples` takes a name and a block. The block typically contains one or more `it` blocks, but it can call any DSL helper that's legal inside a group:

```raku
use BDD::Behave;

shared-examples 'a counter', {
  it 'starts at zero', {
    expect(:start).to.be(0);
  }

  it 'has an increment step', {
    expect(:step).to.be(1);
  }
};
```

The block does nothing on its own — it's stored under the given name and only runs when a group asks for it.

## `it-behaves-like`: wrap shared examples in a nested group

The most common form is `it-behaves-like 'name'`. It creates a nested `behaves like 'name'` group inside the current `describe` and runs the shared block there. The wrapper group keeps the shared examples visually grouped in the runner's output:

```raku
describe 'an integer counter', {
  let(:start, { 0 });
  let(:step,  { 1 });

  it-behaves-like 'a counter';
}
```

Output:

```
⮑  'an integer counter'
  ⮑  'behaves like 'a counter''
    ⮑  'starts at zero'
      ⮑  SUCCESS
    ⮑  'has an increment step'
      ⮑  SUCCESS
```

The shared examples see `let` definitions, hooks, and shared-context contributions from every ancestor group — including the `describe` they're invoked from — exactly the same way ordinary nested examples do.

## `include-examples`: merge shared examples into the current group

`include-examples 'name'` is the lower-ceremony form: the shared block runs directly in the current group, so its `it`s become siblings of any locally-defined `it`s instead of being wrapped in a new group.

```raku
describe 'an integer counter', {
  let(:start, { 0 });
  let(:step,  { 1 });

  include-examples 'a counter';

  it 'is initialized', {
    expect(:start.defined).to.be(True);
  }
}
```

Use `it-behaves-like` when you want the contract to show up as its own labeled subgroup in the output; use `include-examples` when the shared `it`s are conceptually part of the surrounding group.

## Parameterizing shared examples

The shared block can take positional parameters; pass them after the name:

```raku
shared-examples 'a sized collection', -> $expected {
  it "reports its size as $expected", {
    expect($*LET-RUNTIME.value('size')).to.be($expected);
  }
};

describe 'a three-element list', {
  let(:size, { 3 });

  it-behaves-like 'a sized collection', 3;
}
```

Both `it-behaves-like` and `include-examples` forward extra arguments to the shared block.

## Reusing shared examples across multiple groups

Shared examples are typically defined once at the top of a spec file (or in a shared helper file) and referenced from many `describe`s. Each call to `it-behaves-like` or `include-examples` is independent, so you can mix and match per-group setup:

```raku
shared-examples 'a counter', {
  it 'starts at zero', { expect(:start).to.be(0); }
  it 'has an increment step', { expect(:step).to.be(1); }
};

describe 'an integer counter', {
  let(:start, { 0 });
  let(:step,  { 1 });
  it-behaves-like 'a counter';
}

describe 'a fractional counter', {
  let(:start, { 0 });
  let(:step,  { 1 });
  it-behaves-like 'a counter';
  it-behaves-like 'a counter';   # multiple invocations are fine
}
```

## Errors

- Calling `it-behaves-like` or `include-examples` with an unregistered name dies with `Unknown shared examples: '<name>'`.
- Calling `it-behaves-like` or `include-examples` outside a `describe` or `context` block dies — shared examples can only be instantiated inside a group.
