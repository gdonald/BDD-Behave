# expect

`expect` builds an expectation about an actual value. The current matcher is `be`, which uses Raku's smartmatch operator (`~~`).

## Basic form

```raku
expect(actual).to.be(expected);
```

`expect` returns a builder, `.to` is a no-op for readability, and `.be(expected)` performs the comparison.

```raku
it 'compares values', {
  expect(1 + 1).to.be(2);
  expect('hi'.uc).to.be('HI');
  expect(@list).to.be([1, 2, 3]);
}
```

## Smartmatch semantics

Because `be` uses `~~` (via the built-in `BeMatcher`), you can match against types, regexes, ranges, junctions, and anything else Raku smartmatches:

```raku
expect(42).to.be(Int);              # type
expect('hello').to.be(/hell/);      # regex
expect(5).to.be(1..10);             # range
expect($x).to.be(any(1, 2, 3));     # junction
```

Plain values are wrapped in `BeMatcher` automatically. To plug in your own logic, pass any object that does the [`Matcher`](matchers.md) role.

## Negation

`.not` flips the comparison:

```raku
expect(1 + 1).to.not.be(3);
```

## Reading from `let`

`expect` recognises a single named-pair argument as a let lookup:

```raku
let(:answer, { 42 });

it 'matches the let', {
  expect(:answer).to.be(42);
}
```

You can also pass a `Pair` as the *expected* value to read from a let:

```raku
let(:answer, { 42 });

it 'compares two lets', {
  expect(:answer).to.be(:answer);
}
```

For more flexible let access, prefer the binding syntax shown in [`let`](let.md).

## Failure output

When an expectation fails, the runner records the file and line of the `expect` call and prints them in the failure summary so you can jump straight to the offending line.

For diffable shapes (strings, arrays, hashes, sets, bags, mixes), the failure block also includes a colorized `Diff:` section that highlights only the changed regions. See [Diff Output](diff.md) for the full conventions.

## Custom matchers

`be` accepts any object that does the [`Matcher`](matchers.md) role. The matcher's `matches`, `failure-message`, and `failure-message-negated` methods drive the result and the failure summary, so user-defined matchers plug in the same way as the built-in ones.
