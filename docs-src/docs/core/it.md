# it

`it` defines a single example. The first argument is a human-readable description, the second is a block containing the test body.

```raku
describe 'Array', {
  it 'reports its element count', {
    expect((1, 2, 3).elems).to.be(3);
  }
}
```

## One-liner form

The description is optional. When omitted, Behave derives the description from the first matcher used in the block:

```raku
describe 'Array', {
  subject({ (1, 2, 3) });

  it { is-expected.to.be((1, 2, 3)) }
}
```

renders as `⮑  'should be (1, 2, 3)'`. If no matcher runs in the block, Behave falls back to a placeholder of the form `example at <basename>:<line>`. See [`subject` / `is-expected`](../let/subject.md#one-liner-it-form) for details.

## Multiple expectations

An example can contain any number of `expect` calls. Each failing expectation is recorded. The example fails if at least one expectation fails or the block raises an unhandled exception.

```raku
it 'a User is valid after construction', {
  my $u = User.new(:name<Ada>, :age(36));
  expect($u.name).to.be('Ada');
  expect($u.age).to.be(36);
  expect($u.valid).to.be(True);
}
```

## Pending examples

Mark an example as pending with the [`pending`](pending.md) helper. While iterating, you can also comment out the body or leave the assertion unwritten until you implement the behavior.

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

## `specify` alias

`specify` is a direct alias for `it`. It reads more naturally when an example description starts with a non-behavioral noun (a fact, a constraint, a state) rather than a verb. Every form `it` accepts (string + block, block-only one-liner, `:tag` / `:tags` / arbitrary `:meta` keys) is also accepted by `specify`.

```raku
describe 'a fresh User', {
  specify 'name defaults to anonymous', {
    expect(User.new.name).to.be('anonymous');
  }

  specify 'email is empty', {
    expect(User.new.email).to.be('');
  }
}
```

`specify` is a registration-only alias: it does not introduce its own focus / skip / metadata semantics. Mix and match with `it` in the same `describe` as you prefer.

## `example` alias

`example` is another direct alias for `it`, useful when "example" reads more naturally in the test text than "it" or "specify". Like `specify`, it accepts every form `it` does (string + block, block-only one-liner, metadata).

```raku
describe 'String.split', {
  example 'with a single character separator', {
    expect('a,b,c'.split(',')).to.eq(<a b c>);
  }

  example 'with a regex separator', {
    expect('a1b2c'.split(/\d/)).to.eq(<a b c>);
  }
}
```
