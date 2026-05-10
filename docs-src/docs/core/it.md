# it

`it` defines a single example. The first argument is a human-readable description, the second is a block containing the test body.

```raku
describe 'Array', {
  it 'reports its element count', {
    expect((1, 2, 3).elems).to.be(3);
  }
}
```

## Multiple expectations

An example can contain any number of `expect` calls. Each failing expectation is recorded; the example fails if at least one expectation fails or the block raises an unhandled exception.

```raku
it 'a User is valid after construction', {
  my $u = User.new(:name<Ada>, :age(36));
  expect($u.name).to.be('Ada');
  expect($u.age).to.be(36);
  expect($u.valid).to.be(True);
}
```

## Pending examples

You can mark an example as pending by setting its `pending` flag on the returned object (advanced). The simplest path is to comment out the body or skip writing the assertion until you implement the behavior.

## Optional context parameter

If your example block accepts a positional parameter, Behave passes a context object that lets you reach `let` values via method-style access:

```raku
context 'with a let context parameter', {
  let(:widget, { Widget.new(:bar(88)) });

  it 'reads the widget via .', -> $_ {
    expect(.widget.bar).to.be(88);
  }
}
```

See [`let`](../let/let.md) for the various ways to define and consume let values.
