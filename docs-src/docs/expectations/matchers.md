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

| Method                             | Required? | Purpose                                                                                                                                 |
| ---------------------------------- | --------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| `matches($actual)`                 | yes       | Return `True` / `False` for whether `$actual` matches.                                                                                  |
| `failure-message($actual)`         | no        | Message rendered when the expectation fails (positive form). Default: undefined `Str` (falls back to `Expected:` / `to be:` rendering). |
| `failure-message-negated($actual)` | no        | Message rendered when a `.not` expectation fails. Default: undefined `Str`.                                                             |
| `expected-value`                   | no        | The value stored in `Failure.expected` for tooling.                                                                                     |
| `description`                      | no        | Human-readable description, useful for error reporting and reflection.                                                                  |

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

## StartWithMatcher (built-in)

`start-with` checks that a sequence (Array, List) begins with the supplied
items, or that a string begins with each supplied prefix:

```raku
expect([1, 2, 3]).to.start-with(1);            # passes
expect([1, 2, 3]).to.start-with(1, 2);         # passes (in-order prefix)
expect([1, 2, 3]).to.start-with(2);            # fails
expect([1, 2, 3]).to.start-with(2, 1);         # fails (out of order)
expect([1]).to.start-with(1, 2);               # fails (prefix longer)

expect('hello world').to.start-with('hello');         # passes
expect('hello world').to.start-with('hello', 'h');    # passes (each prefix AND)
expect('hello world').to.start-with('hello', 'world');# fails ('world' is not a prefix)
```

For `Positional` / `Iterable` actuals, the args form an in-order prefix matched
via `eqv`. For `Str` actuals, each arg must independently be a prefix of the
string (AND semantics).

The slurp is non-flattening, so passing a single array (`start-with([1, 2])`)
looks for that array as one prefix element. To spread an existing array, use
`|@arr`.

`start-with` rejects undefined or non-iterable, non-string actuals. Empty arg
lists die with `start-with requires at least one item`.

Failure messages render as `expected <actual> to start with <items>` (or `not
to start with` under `.not`).

## EndWithMatcher (built-in)

`end-with` mirrors `start-with` for the trailing end of a sequence or string:

```raku
expect([1, 2, 3]).to.end-with(3);              # passes
expect([1, 2, 3]).to.end-with(2, 3);           # passes (in-order suffix)
expect([1, 2, 3]).to.end-with(2);              # fails
expect([1, 2, 3]).to.end-with(3, 2);           # fails (out of order)
expect([1]).to.end-with(1, 2);                 # fails (suffix longer)

expect('hello world').to.end-with('world');           # passes
expect('hello world').to.end-with('world', 'd');      # passes (each suffix AND)
expect('hello world').to.end-with('world', 'hello');  # fails ('hello' is not a suffix)
```

Same slurp / type / empty-arg conventions as `start-with`. Failure messages
render as `expected <actual> to end with <items>` (or `not to end with` under
`.not`).

## AllMatcher (built-in)

`all` checks that **every element** of a collection matches an inner matcher.
The inner argument is either a plain value (wrapped in `BeMatcher`, smartmatch
semantics) or any object that does `Matcher`:

```raku
expect([1, 1, 1]).to.all(1);                # plain value via BeMatcher
expect([1, 2, 3]).to.all(Int);              # type
expect([1, 5, 10]).to.all(1..10);           # range
expect(['foo', 'food']).to.all(/^foo/);     # regex

expect([1, 2, 3]).to.all(PositiveMatcher.new);          # custom matcher
expect([[1, 2], [1, 3]]).to.all(                        # composes with built-ins
  StartWithMatcher.new(:expected([1]))
);
```

An empty collection passes vacuously:

```raku
expect([]).to.all(Int);                     # passes
expect(()).to.all(1);                       # passes
```

Undefined or non-iterable actuals fail with a shape failure message
(`expected ... to be a collection ...`). For sequence actuals, the matcher
iterates `$actual.list`, so `Hash` actuals are iterated as `Pair`s.

Failure messages render as
`expected <actual> to all <inner-description> (element at index N: <item> did not match)`,
pointing at the **first** failing element. Negation renders as
`expected <actual> not to all <inner-description>`.

### Composing across collections of collections

`all` is most useful when the inner matcher is itself a structural matcher:

```raku
my @rows = [
  { id => 1, status => 'ok' },
  { id => 2, status => 'ok' },
];

expect(@rows).to.all(IncludeMatcher.new(:expected([status => 'ok'])));
```

### Junctions

Pass junctions through `.all(...)` directly — the method binds its argument
raw so junctions are not autothreaded out:

```raku
expect([1, 2, 3]).to.all(any(1, 2, 3));
```

## BeAMatcher (built-in)

`be-a` checks whether the actual value is "of" a given type, including
subclasses, composed roles, and `subset` types. Internally it smartmatches
the actual value against the type (`$actual ~~ $type`):

```raku
expect(42).to.be-a(Int);              # passes
expect(42).to.be-a(Numeric);          # passes (Int is Numeric)
expect('hi').to.be-a(Int);            # fails

class Animal {}
class Dog is Animal {}
expect(Dog.new).to.be-a(Animal);      # passes (subclass)

role Walkable { method walk { } }
class Bird does Walkable {}
expect(Bird.new).to.be-a(Walkable);   # passes (role composition)

subset Positive of Int where * > 0;
expect(5).to.be-a(Positive);          # passes
expect(-1).to.be-a(Positive);         # fails (where clause)
```

`be-an` is provided as an alias for English grammar — it behaves identically:

```raku
expect(42).to.be-an(Int);
```

Failure messages render as `expected <actual> to be a <type>` (or `not to be
a <type>` under `.not`). The type name comes from `$type.^name`.

## BeAnInstanceOfMatcher (built-in)

`be-an-instance-of` is a **strict** type check: the actual value's runtime
type must be exactly the given type. Subclasses, composed roles, and subsets
do not match. Internally it checks `$actual.defined && $actual.WHAT === $type`:

```raku
expect(Dog.new).to.be-an-instance-of(Dog);      # passes
expect(Dog.new).to.be-an-instance-of(Animal);   # fails (subclass)
expect(42).to.be-an-instance-of(Int);           # passes
expect(42).to.be-an-instance-of(Numeric);       # fails (parent role)
```

Type objects (the uninstantiated type itself) do not match:

```raku
expect(Int).to.be-an-instance-of(Int);          # fails (Int is undefined)
```

Because composed roles and subsets are not the runtime type of any concrete
object, `be-an-instance-of(SomeRole)` and `be-an-instance-of(SomeSubset)`
always fail. Use `be-a` for those cases.

Failure messages render as `expected <actual> to be an instance of <type>`
(or `not to be an instance of <type>` under `.not`).

## RespondToMatcher (built-in)

`respond-to` checks whether the actual value has one or more methods.
Internally it uses the meta-object protocol's `^can` introspection
(`$actual.^can($name)`), so it works on both instances and type objects,
and recognises methods supplied by composed roles and parent classes.

```raku
class Calculator {
  method add($a, $b) { $a + $b }
  method subtract($a, $b) { $a - $b }
}

expect(Calculator.new).to.respond-to('add');                # passes
expect(Calculator.new).to.respond-to('add', 'subtract');    # passes
expect(Calculator.new).to.respond-to('multiply');           # fails

role Greeter { method greet { 'hello' } }
class Person does Greeter { }
expect(Person.new).to.respond-to('greet');                  # passes (via role)

expect('hello').to.respond-to('uc', 'lc', 'chars');         # built-ins work
expect([1, 2, 3]).to.respond-to('push', 'pop');             # Arrays too
```

Multiple method names are AND-combined — every name must be present for
the expectation to pass. When the expectation fails, the failure message
lists the missing methods:

```text
expected Dog.new to respond to "bark", "meow", "purr" (missing: "meow", "purr")
```

Negation works the usual way:

```raku
expect(Dog.new).to.not.respond-to('meow');
```

Failure messages render as `expected <actual> to respond to <names>`
(or `not to respond to <names>` under `.not`).

## HaveAttributesMatcher (built-in)

`have-attributes` checks several attributes of an object in one call.
Each named pair maps an attribute name to an expected value (or to
another `Matcher`). For each pair, the matcher calls the accessor on
the actual value and compares — values are compared with `eqv`, and
when the expected side is itself a `Matcher` its `matches` method is
delegated to.

```raku
class Person {
  has Str $.name;
  has Int $.age;
}

my $alice = Person.new(:name<Alice>, :age(30));

expect($alice).to.have-attributes(:name<Alice>, :age(30));     # passes
expect($alice).to.have-attributes(:name<Alice>);               # subset OK
expect($alice).to.have-attributes(:age(31));                   # fails
```

Multiple attributes are AND-combined — every pair must match. When the
expectation fails, the failure message separates *missing* accessors
(the object does not respond to the name at all) from *mismatched*
values (accessor exists, but the value disagrees):

```text
expected Person.new(name => "Alice", age => 30) to have attributes age => 31, nickname => "Al" (missing: "nickname"; mismatched: age: got 30, wanted 31)
```

The matcher composes naturally with other matchers — pass a `Matcher`
instance as the expected value for any attribute:

```raku
use BDD::Behave::Matcher;

expect($alice).to.have-attributes(
  :name(StartWithMatcher.new(:expected(['A']))),
  :age(BeAMatcher.new(:type(Int))),
);
```

Negation works the usual way:

```raku
expect($alice).to.not.have-attributes(:age(31));
```

Failure messages render as `expected <actual> to have attributes
<pairs>` (or `not to have attributes <pairs>` under `.not`).

## Comparison matchers (built-in)

Four matchers cover numeric ordering:

| Matcher                       | Operator | Aliases  |
| ----------------------------- | -------- | -------- |
| `be-greater-than`             | `>`      | `be-gt`  |
| `be-greater-than-or-equal-to` | `>=`     | `be-gte` |
| `be-less-than`                | `<`      | `be-lt`  |
| `be-less-than-or-equal-to`    | `<=`     | `be-lte` |

```raku
expect(5).to.be-greater-than(3);
expect(5).to.be-greater-than-or-equal-to(5);
expect(3).to.be-less-than(5);
expect(5).to.be-less-than-or-equal-to(5);

expect(5).to.be-gt(3);
expect(5).to.be-gte(5);
expect(3).to.be-lt(5);
expect(5).to.be-lte(5);
```

All four accept any `Real` value, so `Int`, `Rat`, and `Num` mix freely
and negatives / zero behave as expected:

```raku
expect(1.5).to.be-greater-than(1.4);     # Rat vs Rat
expect(5).to.be-greater-than(4.99);      # Int vs Rat
expect(3.14e0).to.be-greater-than(3.0e0); # Num vs Num
expect(-1).to.be-greater-than(-5);
expect(0).to.not.be-greater-than(0);
```

Each matcher fails (rather than dying) when `$actual` is undefined or
is not a `Real`, so a stray `Int`-typed `Nil` or a `Str` produces a
recorded failure instead of a runtime error:

```raku
expect(Int).to.be-greater-than(0);  # records a failure
expect('abc').to.be-less-than(10);  # records a failure
```

Negation works the usual way:

```raku
expect(3).to.not.be-greater-than(5);
expect(7).to.not.be-less-than(5);
```

Failure messages render as `expected <actual> to be greater than
<expected>` (and the obvious variants for the other three), or `not to
be …` under `.not`.

## BeBetweenMatcher (built-in)

`be-between` checks whether a numeric `actual` falls within a `[min, max]`
range. The matcher is inclusive by default; chain `.exclusive` (or the
explicit `.inclusive`) to flip the mode:

```raku
expect(5).to.be-between(1, 10);              # inclusive (default), passes
expect(1).to.be-between(1, 10);              # inclusive: lower bound passes
expect(10).to.be-between(1, 10);             # inclusive: upper bound passes

expect(5).to.be-between(1, 10).exclusive;    # exclusive: passes strictly inside
expect(1).to.be-between(1, 10).exclusive;    # exclusive: lower bound fails
expect(10).to.be-between(1, 10).exclusive;   # exclusive: upper bound fails

expect(5).to.be-between(1, 10).inclusive;    # equivalent to the default
```

All four call sites use the same chainable expectation. Re-chaining a
modifier *replaces* any previously recorded failure, so
`expect(10).to.be-between(1, 10).exclusive.inclusive` ends with no
failure: the `.exclusive` step pushes one, then `.inclusive` clears it
when the re-evaluation passes.

`be-between` accepts any `Real` actual, so `Int`, `Rat`, and `Num` mix
freely and negative / zero bounds behave the obvious way:

```raku
expect(1.5).to.be-between(1.0, 2.0);
expect(2).to.be-between(1.5, 2.5);
expect(-3).to.be-between(-5, -1);
expect(0).to.be-between(0, 0);
```

The matcher fails (rather than dying) when `$actual` is undefined or is
not a `Real`, so a stray `Int`-typed `Nil` or a `Str` produces a
recorded failure instead of a runtime error:

```raku
expect(Int).to.be-between(0, 10);            # records a failure
expect('abc').to.be-between(0, 10);          # records a failure
```

Negation works the usual way, and composes with the inclusive / exclusive
modifiers:

```raku
expect(0).to.not.be-between(1, 10);
expect(1).to.not.be-between(1, 10).exclusive;
```

Failure messages name both bounds and the active mode:

```text
expected 11 to be between 1 and 10 (inclusive)
expected 10 to be between 1 and 10 (exclusive)
```

`Failure.expected` is populated as `[min, max]` so programmatic
consumers and alternate formatters can introspect the bounds.

## BeWithinMatcher (built-in)

`be-within` performs a tolerance check on a numeric `actual` against an
expected target, parameterized by a `delta`. The call shape uses an
`.of(...)` continuation so the delta and expected target read naturally:

```raku
expect(5.05).to.be-within(0.1).of(5.0);     # passes (|5.05 - 5.0| <= 0.1)
expect(5.1).to.be-within(0.1).of(5.0);      # passes (boundary is inclusive)
expect(5.2).to.be-within(0.1).of(5.0);      # fails
expect(3.14e0).to.be-within(0.01e0).of(3.15e0);  # Num tolerance
```

The boundary is inclusive — `abs(actual - expected) <= delta` — so a
delta of `0` means actual must equal expected exactly:

```raku
expect(5).to.be-within(0).of(5);            # passes
expect(5.0001).to.be-within(0).of(5);       # fails
```

`be-within` accepts any `Real` actual and target, so `Int`, `Rat`, and
`Num` mix freely. Negative values and zero behave the obvious way:

```raku
expect(-5.05).to.be-within(0.1).of(-5.0);
expect(0.05).to.be-within(0.1).of(0);
```

The matcher fails (rather than dying) when either `$actual` or the
target passed to `.of(...)` is undefined or non-`Real`, so a stray
`Int`-typed `Nil` or a `Str` produces a recorded failure instead of a
runtime error:

```raku
expect(Int).to.be-within(0.1).of(5.0);      # records a failure
expect('abc').to.be-within(0.1).of(5.0);    # records a failure
expect(5.0).to.be-within(0.1).of(Int);      # records a failure
```

Negation works the usual way:

```raku
expect(5.2).to.not.be-within(0.1).of(5.0);  # passes (outside tolerance)
expect(5.05).to.not.be-within(0.1).of(5.0); # fails (inside tolerance)
```

Failure messages render the delta and expected target:

```text
expected 5.2 to be within 0.1 of 5.0
expected 5.05 not to be within 0.1 of 5.0
```

`Failure.expected` is populated with the expected target (not the
delta), and `Failure.given` holds the actual value, so programmatic
consumers and alternate formatters can introspect both.

## BeTruthyMatcher (built-in)

`be-truthy` checks Raku's boolean coercion of the actual value (`?$actual`).
Anything that coerces to `True` passes; anything that coerces to `False`
fails:

```raku
expect(True).to.be-truthy;
expect(1).to.be-truthy;
expect('hello').to.be-truthy;
expect([1, 2, 3]).to.be-truthy;
expect({ a => 1 }).to.be-truthy;

expect(False).to.not.be-truthy;
expect(0).to.not.be-truthy;
expect('').to.not.be-truthy;
expect([]).to.not.be-truthy;
expect(Nil).to.not.be-truthy;
expect(Int).to.not.be-truthy;        # undefined type object
```

Raku's coercion may surprise users coming from Perl: non-empty strings
are always truthy (`'0'.Bool` is `True`), but an empty `Array` / `Hash`
is `False`:

```raku
expect('0').to.be-truthy;        # non-empty string in Raku
expect([]).to.not.be-truthy;
expect({}).to.not.be-truthy;
```

`be-truthy` takes no arguments. Negation works the usual way:

```raku
expect(0).to.not.be-truthy;
```

Failure messages render as `expected <actual> to be truthy` (or `not to
be truthy` under `.not`).

## BeFalsyMatcher (built-in)

`be-falsy` is the inverse of `be-truthy` — it passes when `!$actual` is
`True`:

```raku
expect(False).to.be-falsy;
expect(0).to.be-falsy;
expect('').to.be-falsy;
expect([]).to.be-falsy;
expect({}).to.be-falsy;
expect(Nil).to.be-falsy;
expect(Int).to.be-falsy;            # undefined type object

expect(True).to.not.be-falsy;
expect(1).to.not.be-falsy;
expect('hello').to.not.be-falsy;
expect([1, 2, 3]).to.not.be-falsy;
```

`be-falsy` takes no arguments. Failure messages render as
`expected <actual> to be falsy` (or `not to be falsy` under `.not`).

## BeNilMatcher (built-in)

`be-nil` passes when the actual value is undefined (`!$actual.defined`).
That covers Raku's three flavors of "not a value":

- `Nil` itself
- `Any` (the default for an unassigned scalar)
- any type object, including built-ins like `Int`/`Str` and user-defined classes

```raku
expect(Nil).to.be-nil;
expect(Any).to.be-nil;
expect(Int).to.be-nil;          # undefined built-in type object
expect(Str).to.be-nil;

my class Widget {}
expect(Widget).to.be-nil;       # user-defined type object
expect(Widget.new).to.not.be-nil; # defined instance
```

Defined values — even "empty" or falsy ones — fail `be-nil`:

```raku
expect(0).to.not.be-nil;
expect('').to.not.be-nil;
expect([]).to.not.be-nil;
expect({}).to.not.be-nil;
expect(False).to.not.be-nil;
```

This is the type-object-vs-instance distinction that Raku makes
explicit: `Int` (the type) is undefined, but `0` (an instance of
`Int`) is defined. Use `be-nil` when you care about "is this a real
value", and `be-falsy` when you care about boolean coercion (which
treats empty collections as false too).

Note that assigning `Nil` to a plain `my $x` reverts `$x` to `Any` —
both still pass `be-nil`, so the distinction rarely matters in
practice.

`be-nil` takes no arguments. Failure messages render as
`expected <actual.raku> to be nil` (or `not to be nil` under `.not`).

## MatchMatcher (built-in)

`match` passes when a `Str` actual value smartmatches against a `Regex`
expected value (`$actual ~~ /pattern/`). It accepts the full Raku regex
syntax, including character classes, alternation, anchors, modifiers,
and `rx//`-quoted forms.

```raku
expect('abc123').to.match(/\d+/);
expect('hello world').to.match(/world/);
expect('HELLO').to.match(rx:i/hello/);     # case-insensitive
expect('hello').to.match(/^hello$/);       # anchored
```

Negation uses the same `.not` chain:

```raku
expect('abc').to.not.match(/\d+/);
expect('cat').to.not.match(/dog/);
```

Undefined and non-`Str` actuals fail rather than throw — `expect(Any)`,
`expect(Str)`, `expect(42)`, and `expect([1, 2, 3])` all record a
failure when matched against any regex, so a stray nil or wrongly typed
value produces a normal expectation failure instead of a runtime
exception.

Failure messages render the actual value and the regex via `.raku`:

```
expected "abc" to match /\d+/
expected "abc123" not to match /\d+/
```

`Failure.given` carries the original string and `Failure.expected`
carries the `Regex` itself, so programmatic consumers and alternate
formatters can inspect either side.

`match` is regex-only; for substring checks use `include` (see
[Matchers › IncludeMatcher](matchers.md#includematcher-built-in)).

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
