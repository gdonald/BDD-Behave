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
