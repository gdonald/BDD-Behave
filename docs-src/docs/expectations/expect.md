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

Plain values are wrapped in `BeMatcher` automatically. To plug in your own logic, pass any object that does the [`Matcher`](matchers.md) role — or use [`define-matcher`](custom-matchers.md) for the lighter, callback-based form. Combine matchers with `.and` / `.or`; see [Composable Matchers](composable-matchers.md). For Raku-native `any` / `all` / `one` / `none` junctions, see [Junctions](junctions.md).

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

For other ways to read a let, see [`let`](../let/let.md).

## Failure output

When an expectation fails, the runner records the file and line of the `expect` call and prints them in the failure summary so you can jump straight to the offending line.

For diffable shapes (strings, arrays, hashes, sets, bags, mixes), the failure block also includes a colorized `Diff:` section that highlights only the changed regions. See [Diff Output](../diff/diff.md) for the full conventions.

## Built-in matchers beyond `be`

`expect(...).to.<matcher>(...)` is the general form. The current built-ins:

| Matcher                                  | Purpose                                                                                                                                                                                                                                                                                                                                                                                                      |
| ---------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `be`                                     | Smartmatch (`~~`) against the expected value.                                                                                                                                                                                                                                                                                                                                                                |
| `eq`                                     | Order-dependent structural equality via `eqv`. See [Matchers › EqMatcher](matchers.md#eqmatcher-built-in).                                                                                                                                                                                                                                                                                                   |
| `contain-exactly`                        | Order-independent multiset equality on arrays / lists. See [Matchers › ContainExactlyMatcher](matchers.md#containexactlymatcher-built-in).                                                                                                                                                                                                                                                                   |
| `match-array`                            | Single-array alias for `contain-exactly`.                                                                                                                                                                                                                                                                                                                                                                    |
| `include`                                | Membership check across arrays, hashes, sets/bags, strings, and ranges. See [Matchers › IncludeMatcher](matchers.md#includematcher-built-in).                                                                                                                                                                                                                                                                |
| `start-with`                             | Sequence prefix check for arrays / lists; per-arg prefix check for strings. See [Matchers › StartWithMatcher](matchers.md#startwithmatcher-built-in).                                                                                                                                                                                                                                                        |
| `end-with`                               | Sequence suffix check for arrays / lists; per-arg suffix check for strings. See [Matchers › EndWithMatcher](matchers.md#endwithmatcher-built-in).                                                                                                                                                                                                                                                            |
| `all`                                    | Every element of a collection must match an inner matcher. See [Matchers › AllMatcher](matchers.md#allmatcher-built-in).                                                                                                                                                                                                                                                                                     |
| `be-a` / `be-an`                         | Type check including subclasses, roles, and subsets (`$actual ~~ $type`). See [Matchers › BeAMatcher](matchers.md#beamatcher-built-in).                                                                                                                                                                                                                                                                      |
| `be-an-instance-of`                      | Strict runtime-type check (`$actual.WHAT === $type`, requires defined). See [Matchers › BeAnInstanceOfMatcher](matchers.md#beaninstanceofmatcher-built-in).                                                                                                                                                                                                                                                  |
| `respond-to`                             | Method-presence check via `$actual.^can(...)`. Accepts one or more method names. See [Matchers › RespondToMatcher](matchers.md#respondtomatcher-built-in).                                                                                                                                                                                                                                                   |
| `have-attributes`                        | Multi-attribute check: each named pair calls the accessor on `$actual` and compares (`eqv`, or an inner `Matcher`). See [Matchers › HaveAttributesMatcher](matchers.md#haveattributesmatcher-built-in).                                                                                                                                                                                                      |
| `be-greater-than` / `be-gt`              | Numeric `>` comparison; fails (not dies) on undefined or non-`Real` actuals. See [Matchers › Comparison matchers](matchers.md#comparison-matchers-built-in).                                                                                                                                                                                                                                                 |
| `be-greater-than-or-equal-to` / `be-gte` | Numeric `>=` comparison.                                                                                                                                                                                                                                                                                                                                                                                     |
| `be-less-than` / `be-lt`                 | Numeric `<` comparison.                                                                                                                                                                                                                                                                                                                                                                                      |
| `be-less-than-or-equal-to` / `be-lte`    | Numeric `<=` comparison.                                                                                                                                                                                                                                                                                                                                                                                     |
| `be-between`                             | Range check between two `Real` bounds. Inclusive by default; chain `.exclusive` or `.inclusive` to flip the mode. See [Matchers › BeBetweenMatcher](matchers.md#bebetweenmatcher-built-in).                                                                                                                                                                                                                  |
| `be-within`                              | Tolerance check: `be-within($delta).of($expected)` passes when `abs(actual - expected) <= delta`. See [Matchers › BeWithinMatcher](matchers.md#bewithinmatcher-built-in).                                                                                                                                                                                                                                    |
| `be-truthy`                              | Boolean coercion check (`?$actual`); empty `Array`/`Hash`, `Nil`, and undefined type objects are not truthy. See [Matchers › BeTruthyMatcher](matchers.md#betruthymatcher-built-in).                                                                                                                                                                                                                         |
| `be-falsy`                               | Inverse of `be-truthy` (`!$actual`). See [Matchers › BeFalsyMatcher](matchers.md#befalsymatcher-built-in).                                                                                                                                                                                                                                                                                                   |
| `be-nil`                                 | Undefined-value check (`!$actual.defined`); passes for `Nil`, `Any`, and undefined type objects. See [Matchers › BeNilMatcher](matchers.md#benilmatcher-built-in).                                                                                                                                                                                                                                           |
| `match`                                  | Regex match against a `Str` (`$actual ~~ /pattern/`); fails (not dies) on undefined or non-`Str` actuals. See [Matchers › MatchMatcher](matchers.md#matchmatcher-built-in).                                                                                                                                                                                                                                  |
| `raise-error`                            | Passes when a `Callable` actual raises an exception when invoked. Wrap the code under test in `{ ... }`. Forms: `raise-error`, `raise-error(Type)`, `raise-error(Type, /pattern/)`, `raise-error(/pattern/)`. Chain `.with-message($str-or-regex)` to filter by exception message (`Str` compares with `eq`, `Regex` with `~~`). See [Matchers › RaiseErrorMatcher](matchers.md#raiseerrormatcher-built-in). |
| `change`                                 | Passes when a `Callable` action changes the value returned by an observable block (compared with `eqv`). Wrap the action and the observable in `{ ... }`. Chain `.from(value)` / `.to(value)` to constrain the start and / or end value, or `.by(delta)` / `.by-at-least(delta)` / `.by-at-most(delta)` for numeric deltas. See [Matchers › ChangeMatcher](matchers.md#changematcher-built-in).             |
| `be-kept`                                | Passes when a `Promise` actual settles in the `Kept` state. Blocks up to a default 5-second timeout; pass `be-kept($seconds)` for a custom timeout. Surfaces the broken cause in failure messages. See [Matchers › BeKeptMatcher](matchers.md#bekeptmatcher-built-in).                                                                                                                                       |
| `be-broken`                              | Passes when a `Promise` actual settles in the `Broken` state. Same timeout shape as `be-kept`. Surfaces the kept value or the broken cause in failure messages. See [Matchers › BeBrokenMatcher](matchers.md#bebrokenmatcher-built-in).                                                                                                                                                                      |
| `complete-within`                        | Passes when a `Promise` actual settles (kept or broken) within the given duration (`Real` seconds). See [Matchers › CompleteWithinMatcher](matchers.md#completewithinmatcher-built-in).                                                                                                                                                                                                                      |
| `emit`                                   | Passes when a `Supply` or `Channel` actual emits exactly the given values (compared via `eqv`) within the collection window. Pass `:within($seconds)` to change the default 1-second window. See [Matchers › EmitMatcher](matchers.md#emitmatcher-built-in).                                                                                                                                                |
| `emit-at-least`                          | Passes when a `Supply` or `Channel` actual emits at least the given count of values within the collection window. Pass `:within($seconds)` to change the default 1-second window. See [Matchers › EmitAtLeastMatcher](matchers.md#emitatleastmatcher-built-in).                                                                                                                                              |
| `complete`                               | Passes when a `Supply` (sending `done`) or `Channel` (closed) completes within the collection window. Pass `:within($seconds)` to change the default 1-second window. See [Matchers › CompleteMatcher](matchers.md#completematcher-built-in).                                                                                                                                                                |
| `eventually`                             | Re-runs a `Callable` actual on a polling loop until the chained inner matcher passes or the timeout elapses. Chain any matcher method (`be`, `eq`, `match`, `include`, `be-truthy`, `be-greater-than`, ...) or pass a `Matcher` instance via `.matches-with`. Configure with `eventually(:timeout(s), :interval(s))` (defaults: 2s / 0.05s). Useful for eventually-consistent state. See [Matchers › EventuallyMatcher](matchers.md#eventuallymatcher-built-in). |

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
my $counter = 0;
expect({ $counter++ }).to.change({ $counter });
expect({ 1 + 1 }).to.not.change({ $counter });
my $balance = 0;
expect({ $balance = 100 }).to.change({ $balance }).from(0).to(100);
expect({ $balance += 50 }).to.change({ $balance }).from(100);
expect({ $balance -= 150 }).to.change({ $balance }).to(0);
expect({ $balance += 25 }).to.change({ $balance }).by(25);
expect({ $balance -= 10 }).to.change({ $balance }).by(-10);
expect({ $balance += 5 }).to.change({ $balance }).by-at-least(1).by-at-most(10);
expect(Promise.kept('done')).to.be-kept;
expect(Promise.broken('boom')).to.be-broken;
expect(start { compute() }).to.be-kept(0.5);
expect(Promise.kept('done')).to.complete-within(1);
expect(Promise.new).to.not.complete-within(0.05);
expect(Supply.from-list(1, 2, 3)).to.emit(1, 2, 3);
expect(Supply.from-list(1, 2, 3, 4)).to.emit-at-least(2);
expect(Supply.from-list(1, 2)).to.complete;
expect({ get-status() }).to.eventually.be('done');
expect({ counter() }).to.eventually(:timeout(5), :interval(0.1)).be-greater-than(100);
expect({ load() }).to.not.eventually(:timeout(0.1)).be('error');
```

## Custom matchers

`be` accepts any object that does the [`Matcher`](matchers.md) role. The matcher's `matches`, `failure-message`, and `failure-message-negated` methods drive the result and the failure summary, so user-defined matchers plug in the same way as the built-in ones.

## Failure behavior

When an `expect(...)` matcher fails, the failure is recorded on `Failures.list` and the example body **stops executing** — anything after the failing line is skipped. The example is reported once in the run summary regardless of how many `expect` statements its body contained.

This matches RSpec's default. Ideally each `it` block contains exactly one `expect` so the first miss is also the last. When you do need multiple expectations in a single example, wrap them in `aggregate-failures { ... }`; the throw is suppressed inside the block, every expectation runs, and the inner failures are rolled up into a single labeled `Failures` row at the `aggregate-failures` line. See [aggregate-failures](aggregate-failures.md).

If you're writing meta-tests that deliberately trigger a failure and then inspect the recorded `Failure` records, use `capture-failures { ... }` instead — it suppresses the throw and returns the captured failures without polluting the surrounding example. See [aggregate-failures § `capture-failures` for meta-tests](aggregate-failures.md#capture-failures-for-meta-tests).
