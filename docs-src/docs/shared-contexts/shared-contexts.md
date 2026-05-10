# Shared Contexts

Shared contexts let you package up `let` definitions and hooks under a name, then mix them into any number of `describe` or `context` groups. They're useful when several specs need the same setup — fixtures, logging, an authenticated user — without copy-paste.

`shared-context` and `include-context` are exported from `BDD::Behave`.

## Defining a shared context

`shared-context` takes a name and a block. The block can call any DSL helper that's legal inside a group — `let`, `before-each`, `after-each`, `before-all`, `after-all`, even other `include-context` calls.

```raku
use BDD::Behave;

shared-context 'with widgets', {
  let(:widget, { 'gadget' });
  let(:count,  { 3 });
};
```

A shared context on its own does nothing — it isn't run until a group includes it.

## Including a shared context

Call `include-context 'name'` from inside a `describe` or `context`. The shared block runs in the including group's scope, so its `let` definitions and hooks become part of that group exactly as if you'd written them inline.

```raku
describe 'shared-context inclusion', {
  include-context 'with widgets';

  it 'pulls in lets from the shared context', {
    expect(:widget).to.be('gadget');
    expect(:count).to.be(3);
  }
}
```

## Hooks contributed by a shared context

Hooks declared in a shared context fire around the including group's examples like any other hook in that group:

```raku
shared-context 'with logging', {
  my @log;
  before-each { @log = [] }
  let(:log,   { @log });
};

describe 'shared-context with hooks', {
  include-context 'with logging';

  it 'starts with an empty log per example', {
    expect($*LET-RUNTIME.value('log').elems).to.be(0);
  }
}
```

Because the hook lives in the including group, it inherits into nested `context` blocks the same way an inline hook would. See [Hooks](../hooks/hooks.md) for the full ordering rules.

## Shadowing

A `let` defined in the including group (or any inner group) shadows a `let` of the same name from a shared context:

```raku
shared-context 'with default name', {
  let(:name, { 'default' });
};

describe 'inner let shadows shared-context let', {
  include-context 'with default name';
  let(:name, { 'override' });

  it 'sees the inner value', {
    expect(:name).to.be('override');
  }
}
```

## Parameterized shared contexts

The shared block can take positional parameters; pass them after the name in `include-context`:

```raku
shared-context 'with prefix', -> $prefix {
  let(:greeting, { "$prefix, world" });
};

describe 'parameterized shared context', {
  include-context 'with prefix', 'hello';

  it 'forwards arguments to the shared block', {
    expect(:greeting).to.be('hello, world');
  }
}
```

## Combining shared contexts

A single group can include any number of shared contexts, and nested groups can include their own on top of what they inherit:

```raku
describe 'multiple shared contexts in one group', {
  include-context 'with widgets';
  include-context 'with default name';

  it 'merges lets from both shared contexts', {
    expect(:widget).to.be('gadget');
    expect(:name).to.be('default');
  }
}

describe 'nested groups inherit shared-context contributions', {
  include-context 'with widgets';

  context 'inner context', {
    include-context 'with default name';

    it 'sees lets from outer and inner shared contexts', {
      expect(:widget).to.be('gadget');
      expect(:name).to.be('default');
    }
  }
}
```

## Errors

- Calling `include-context` with an unregistered name dies with `Unknown shared context: '<name>'`.
- Calling `include-context` outside a `describe` or `context` block dies — shared contexts can only be mixed into a group.
