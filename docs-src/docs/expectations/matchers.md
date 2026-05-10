# Matcher Architecture

`expect(...).to.be(...)` is built on top of a small `Matcher` role. The expected
value passed to `.be(...)` is either:

- **a plain value** — wrapped in the built-in `BeMatcher` (smartmatch), or
- **a `Matcher`-doing object** — used directly.

This is the seam every built-in matcher and every user-defined matcher plugs
into.

## The Matcher role

```raku
unit module BDD::Behave::Matcher;

role Matcher is export {
  method matches($actual --> Bool) { ... }
  method failure-message($actual --> Str) { Str }
  method failure-message-negated($actual --> Str) { Str }
  method expected-value(--> Mu) { Nil }
  method description(--> Str) { self.^name }
}
```

| Method | Required? | Purpose |
| --- | --- | --- |
| `matches($actual)` | yes | Return `True` / `False` for whether `$actual` matches. |
| `failure-message($actual)` | no | Message rendered when the expectation fails (positive form). Default: undefined `Str` (falls back to `Expected:` / `to be:` rendering). |
| `failure-message-negated($actual)` | no | Message rendered when a `.not` expectation fails. Default: undefined `Str`. |
| `expected-value` | no | The value stored in `Failure.expected` for tooling. |
| `description` | no | Human-readable description, useful for error reporting and reflection. |

## BeMatcher (built-in)

`BeMatcher` wraps Raku's smartmatch operator (`~~`). When you write:

```raku
expect(42).to.be(42);
expect('hello').to.be(/hell/);
expect(5).to.be(1..10);
expect($x).to.be(any(1, 2, 3));
```

…the runner constructs `BeMatcher.new(:expected(...))` under the hood. Because
`BeMatcher` deliberately leaves `failure-message` undefined, failure rendering
keeps the structured `Expected:` / `to be:` block plus the colorized `Diff:`
section described in [Diff Output](../diff/diff.md).

## EqMatcher (built-in)

`eq` checks order-dependent structural equality using Raku's `eqv` operator.
It's invoked via `expect(...).to.eq(...)`:

```raku
expect([1, 2, 3]).to.eq([1, 2, 3]);            # passes
expect([1, 2, 3]).to.eq([3, 2, 1]);            # fails (order matters)

expect({ a => 1, b => 2 }).to.eq({ a => 1, b => 2 });  # passes
expect(42).to.eq(42);                          # passes
```

`eqv` is type-strict, so an `Array` is not equivalent to a `List` with the same
elements:

```raku
expect([1, 2, 3]).to.eq((1, 2, 3));            # fails (Array vs List)
```

`EqMatcher` deliberately leaves `failure-message` undefined, so failures fall
through to the structured `Expected:` / `to be:` block plus the colorized
`Diff:` section described in [Diff Output](../diff/diff.md).

Negation works the usual way:

```raku
expect([1, 2, 3]).to.not.eq([3, 2, 1]);
```

## ContainExactlyMatcher (built-in)

`contain-exactly` checks order-independent multiset equality on arrays / lists.
Each item in `actual` must correspond to one item in the expected list (matched
by `eqv`), with counts and totals matching:

```raku
expect([1, 2, 3]).to.contain-exactly(3, 1, 2);   # passes
expect([1, 1, 2]).to.contain-exactly(1, 2, 1);   # passes (multiset)
expect([1, 1, 2]).to.contain-exactly(1, 2);      # fails (counts differ)
expect([1, 2, 3]).to.contain-exactly(1, 2);      # fails (extra in actual)
expect([1, 2]).to.contain-exactly(1, 2, 3);      # fails (missing)
```

Items are passed as individual positional arguments. The slurp is
non-flattening, so passing a single array (`contain-exactly([1, 2])`) looks for
that array as one element. To spread an existing array, use `|@arr`:

```raku
my @want = 1, 2, 3;
expect([3, 2, 1]).to.contain-exactly(|@want);
```

The empty form passes for an empty array:

```raku
expect([]).to.contain-exactly();
```

Failure messages render as `expected <actual> to contain exactly <items>` (or
`not to contain exactly` under `.not`).

`match-array` is the array-form alias — it takes a single array argument and
delegates to the same matcher:

```raku
expect([1, 2, 3]).to.match-array([3, 2, 1]);   # passes
expect([1, 2, 3]).to.match-array([1, 2]);      # fails
```

`match-array` requires its argument to be an array / list; passing a scalar
dies with `match-array requires an array argument`.

## IncludeMatcher (built-in)

`include` checks membership across arrays, hashes, sets, bags, ranges, and
strings. It's invoked via `expect(...).to.include(...)`:

```raku
expect([1, 2, 3]).to.include(2);              # array element
expect([1, 2, 3]).to.include(1, 3);           # multiple elements (AND)
expect([[1, 2], [3, 4]]).to.include([1, 2]);  # nested element via eqv

expect({ a => 1, b => 2 }).to.include('a');         # hash key
expect({ a => 1, b => 2 }).to.include(a => 1);      # hash key + value
expect({ a => 1, b => 2 }).to.include(:a(1));       # named-pair shorthand

expect('hello world').to.include('world');    # string substring
expect('hello world').to.include('hello', 'world');

expect(set('a', 'b')).to.include('a');        # Set / Bag membership
expect(1..10).to.include(5);                  # Range membership
```

Multiple items are combined with AND semantics: every item must be present
for the matcher to pass. The slurp is non-flattening, so passing a single
array argument (`include([1, 2])`) looks for that array as one element rather
than spreading it. To spread an existing array, use `|@arr`.

Negation works the usual way:

```raku
expect([1, 2, 3]).to.not.include(99);
```

Failure messages render as `expected <actual> to include <items>` (or `not
to include` under `.not`).

## Writing a custom matcher

Define a class that does `Matcher` and pass an instance to `.be(...)`:

```raku
use BDD::Behave;
use BDD::Behave::Matcher;

class EvenMatcher does Matcher {
  method matches($actual --> Bool) { ?($actual %% 2) }
  method failure-message($actual --> Str) {
    "expected $actual to be even";
  }
  method failure-message-negated($actual --> Str) {
    "expected $actual not to be even";
  }
  method expected-value(--> Mu) { 'an even number' }
}

it 'is even', {
  expect(4).to.be(EvenMatcher.new);          # passes
  expect(5).to.not.be(EvenMatcher.new);      # passes
}
```

When the matcher reports a failure:

- The matcher's `failure-message($actual)` (or `failure-message-negated($actual)`
  for `.not`) becomes `Failure.message` and is what the failure summary prints.
- `Failure.given` holds the actual value, `Failure.expected` holds
  `expected-value`. Both are still useful for programmatic consumers and for
  alternate formatters.

## Negation

`.not` flips the boolean result of `matches` *before* the framework decides
whether to record a failure. Matchers do not need to special-case negation;
they only need to return a sensible message from `failure-message-negated` for
when `.not` fails (i.e., the matcher matched but should not have).

Built-in matchers and user-supplied matchers go through the same role, so a
custom matcher you write integrates with `expect` exactly the way the
built-ins do.
