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

For more flexible let access, prefer the binding syntax shown in [`let`](../let/let.md).

## Failure output

When an expectation fails, the runner records the file and line of the `expect` call and prints them in the failure summary so you can jump straight to the offending line.

For diffable shapes (strings, arrays, hashes, sets, bags, mixes), the failure block also includes a colorized `Diff:` section that highlights only the changed regions. See [Diff Output](../diff/diff.md) for the full conventions.

## Built-in matchers beyond `be`

`expect(...).to.<matcher>(...)` is the general form. The current built-ins:

| Matcher                                  | Purpose                                                                                                                                                                                                 |
| ---------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `be`                                     | Smartmatch (`~~`) against the expected value.                                                                                                                                                           |
| `eq`                                     | Order-dependent structural equality via `eqv`. See [Matchers › EqMatcher](matchers.md#eqmatcher-built-in).                                                                                              |
| `contain-exactly`                        | Order-independent multiset equality on arrays / lists. See [Matchers › ContainExactlyMatcher](matchers.md#containexactlymatcher-built-in).                                                              |
| `match-array`                            | Single-array alias for `contain-exactly`.                                                                                                                                                               |
| `include`                                | Membership check across arrays, hashes, sets/bags, strings, and ranges. See [Matchers › IncludeMatcher](matchers.md#includematcher-built-in).                                                           |
| `start-with`                             | Sequence prefix check for arrays / lists; per-arg prefix check for strings. See [Matchers › StartWithMatcher](matchers.md#startwithmatcher-built-in).                                                   |
| `end-with`                               | Sequence suffix check for arrays / lists; per-arg suffix check for strings. See [Matchers › EndWithMatcher](matchers.md#endwithmatcher-built-in).                                                       |
| `all`                                    | Every element of a collection must match an inner matcher. See [Matchers › AllMatcher](matchers.md#allmatcher-built-in).                                                                                |
| `be-a` / `be-an`                         | Type check including subclasses, roles, and subsets (`$actual ~~ $type`). See [Matchers › BeAMatcher](matchers.md#beamatcher-built-in).                                                                 |
| `be-an-instance-of`                      | Strict runtime-type check (`$actual.WHAT === $type`, requires defined). See [Matchers › BeAnInstanceOfMatcher](matchers.md#beaninstanceofmatcher-built-in).                                             |
| `respond-to`                             | Method-presence check via `$actual.^can(...)`. Accepts one or more method names. See [Matchers › RespondToMatcher](matchers.md#respondtomatcher-built-in).                                              |
| `have-attributes`                        | Multi-attribute check: each named pair calls the accessor on `$actual` and compares (`eqv`, or an inner `Matcher`). See [Matchers › HaveAttributesMatcher](matchers.md#haveattributesmatcher-built-in). |
| `be-greater-than` / `be-gt`              | Numeric `>` comparison; fails (not dies) on undefined or non-`Real` actuals. See [Matchers › Comparison matchers](matchers.md#comparison-matchers-built-in).                                            |
| `be-greater-than-or-equal-to` / `be-gte` | Numeric `>=` comparison.                                                                                                                                                                                |
| `be-less-than` / `be-lt`                 | Numeric `<` comparison.                                                                                                                                                                                 |
| `be-less-than-or-equal-to` / `be-lte`    | Numeric `<=` comparison.                                                                                                                                                                                |
| `be-between`                             | Range check between two `Real` bounds. Inclusive by default; chain `.exclusive` or `.inclusive` to flip the mode. See [Matchers › BeBetweenMatcher](matchers.md#bebetweenmatcher-built-in).             |
| `be-within`                              | Tolerance check: `be-within($delta).of($expected)` passes when `abs(actual - expected) <= delta`. See [Matchers › BeWithinMatcher](matchers.md#bewithinmatcher-built-in).                               |
| `be-truthy`                              | Boolean coercion check (`?$actual`); empty `Array`/`Hash`, `Nil`, and undefined type objects are not truthy. See [Matchers › BeTruthyMatcher](matchers.md#betruthymatcher-built-in).                    |
| `be-falsy`                               | Inverse of `be-truthy` (`!$actual`). See [Matchers › BeFalsyMatcher](matchers.md#befalsymatcher-built-in).                                                                                              |
| `be-nil`                                 | Undefined-value check (`!$actual.defined`); passes for `Nil`, `Any`, and undefined type objects. See [Matchers › BeNilMatcher](matchers.md#benilmatcher-built-in).                                      |
| `match`                                  | Regex match against a `Str` (`$actual ~~ /pattern/`); fails (not dies) on undefined or non-`Str` actuals. See [Matchers › MatchMatcher](matchers.md#matchmatcher-built-in).                             |
| `raise-error`                            | Passes when a `Callable` actual raises an exception when invoked. Wrap the code under test in `{ ... }`. Forms: `raise-error`, `raise-error(Type)`, `raise-error(Type, /pattern/)`, `raise-error(/pattern/)`. Chain `.with-message($str-or-regex)` to filter by exception message (`Str` compares with `eq`, `Regex` with `~~`). See [Matchers › RaiseErrorMatcher](matchers.md#raiseerrormatcher-built-in).                   |

```raku
expect([1, 2, 3]).to.eq([1, 2, 3]);
expect([1, 2, 3]).to.contain-exactly(3, 1, 2);
expect([1, 2, 3]).to.match-array([3, 1, 2]);
expect([1, 2, 3]).to.include(2);
expect({ a => 1 }).to.include(:a(1));
expect('hello').to.include('ell');
expect([1, 2, 3]).to.start-with(1, 2);
expect([1, 2, 3]).to.end-with(2, 3);
expect('hello world').to.start-with('hello');
expect('hello world').to.end-with('world');
expect([1, 2, 3]).to.all(Int);
expect(42).to.be-a(Int);
expect(42).to.be-an(Int);
expect(Dog.new).to.be-an-instance-of(Dog);
expect(Calculator.new).to.respond-to('add', 'subtract');
expect(5).to.be-between(1, 10);
expect(5).to.be-between(1, 10).exclusive;
expect(3.14e0).to.be-within(0.01e0).of(3.15e0);
expect(True).to.be-truthy;
expect(False).to.be-falsy;
expect(Nil).to.be-nil;
expect(Int).to.be-nil;          # undefined type object
expect(42).to.not.be-nil;
expect('abc123').to.match(/\d+/);
expect('HELLO').to.match(rx:i/hello/);
expect({ die "boom" }).to.raise-error;
expect({ 1 + 1 }).to.not.raise-error;
expect({ X::AdHoc.new(payload => 'oops').throw }).to.raise-error(X::AdHoc);
expect({ die "code=42" }).to.raise-error(X::AdHoc, /'code=42'/);
expect({ die "alpha" }).to.raise-error(/alpha/);
expect({ die "boom" }).to.raise-error.with-message('boom');
expect({ die "code=42" }).to.raise-error(X::AdHoc).with-message(/'code=42'/);
```

## Custom matchers

`be` accepts any object that does the [`Matcher`](matchers.md) role. The matcher's `matches`, `failure-message`, and `failure-message-negated` methods drive the result and the failure summary, so user-defined matchers plug in the same way as the built-in ones.
