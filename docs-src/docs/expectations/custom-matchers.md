# Custom Matchers

When the built-in matchers don't quite say what you mean, define your own.
A custom matcher is just a small bundle of callbacks: a `match` predicate plus
optional message/description hooks. It plugs into the same
[Matcher](matchers.md) machinery used by every built-in matcher.

## `define-matcher`

```raku
my &be-a-multiple-of = define-matcher 'be-a-multiple-of',
  match => -> $actual, $expected { ?($actual %% $expected) },
  failure-message =>
    -> $actual, $expected { "expected $actual to be a multiple of $expected" },
  failure-message-negated =>
    -> $actual, $expected { "expected $actual not to be a multiple of $expected" },
  description => -> $expected { "be a multiple of $expected" };

expect(9).to.be(be-a-multiple-of(3));    # passes
expect(8).to.not.be(be-a-multiple-of(3)); # passes
```

`define-matcher` returns a **factory** — call it with the matcher's expected
args and you get back a `DefinedMatcher` instance you can pass into
`expect(...).to.be(...)`. The matcher is also registered globally so other
files can reach it through [`matcher(...)`](#matchername-args-lookup).

### Options

| Option                    | Required? | Block receives                | Purpose                                                                                                                                 |
| ------------------------- | --------- | ----------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| `match`                   | yes       | `$actual, *@args, *%kwargs`   | Predicate. Return truthy to pass.                                                                                                       |
| `failure-message`         | no        | `$actual, *@args, *%kwargs`   | Message rendered when the expectation fails. Default: undefined `Str` (falls back to `Expected:` / `to be:` rendering).                 |
| `failure-message-negated` | no        | `$actual, *@args, *%kwargs`   | Message rendered when a `.not` expectation fails. Default: undefined `Str`.                                                             |
| `description`             | no        | `*@args, *%kwargs`            | Human-readable description (used for failure context and auto-description of `it { ... }`). Default: the matcher name.                  |
| `expected-value`          | no        | `*@args, *%kwargs`            | Value stored in `Failure.expected`. Default: the single arg, the kwargs Map, or the args List depending on what was passed.             |

`match` is the only required block. Anything else can be omitted and you get a
sensible default. The factory you receive is just sugar over the
[registry's `build` method](#the-registry); calling `matcher(...)` directly
works identically.

### Argument shape

Every block receives the matcher's arguments after `$actual`. The shape mirrors
the factory call site:

```raku
my &be-mult = define-matcher 'be-mult',
  match => -> $actual, $n { ?($actual %% $n) };

be-mult(3);          # @args = (3,)
matcher('be-mult', 5); # @args = (5,)
```

Named arguments are also supported and arrive as a slurpy hash:

```raku
my &in-range = define-matcher 'in-range',
  match => -> $actual, :$min, :$max { $actual >= $min && $actual <= $max };

expect(5).to.be(in-range(min => 1, max => 10));
```

## `matcher(name, *args)` lookup

When you only know the matcher's name at runtime, or want to look it up across
files without sharing the factory closure, use `matcher`:

```raku
matcher('be-a-multiple-of', 3);  # returns a DefinedMatcher
expect(9).to.be(matcher('be-a-multiple-of', 3));
```

Looking up an unregistered name dies with a clear message.

## Direct method dispatch via `FALLBACK`

`ExpectationBuilder` falls back to the custom-matcher registry for any unknown
method name, so once a matcher is registered you can call it as if it were a
built-in:

```raku
define-matcher 'be-positive',
  match => -> $actual { $actual > 0 },
  failure-message => -> $actual { "expected $actual to be positive" };

expect(5).to.be-positive;            # passes
expect(-1).to.be-positive;           # fails, with the custom message
expect(-1).to.not.be-positive;       # passes
```

Existing methods on `ExpectationBuilder` (`be`, `eq`, `include`, ...) take
precedence over the registry, and unknown names that aren't registered still
raise `X::Method::NotFound` — so a typo doesn't get silently swallowed.

## How it plugs in

A `DefinedMatcher` `does Matcher`, so it goes through the exact same code path
as the built-in matchers:

- `expect(x).to.be($matcher)` calls `$matcher.matches($actual)`.
- On a miss, `Failures` records the matcher's `failure-message($actual)` (or
  the negated variant under `.not`).
- If you omit `failure-message`, the failure renders through the structured
  `Expected:` / `to be:` block plus the
  [diff](../diff/diff.md) section, exactly like `BeMatcher`.

This means custom matchers compose with everything else the runner already
does: `.not`, the
[matcher architecture](matchers.md), [aggregate-failures](aggregate-failures.md),
and one-liner [auto-descriptions](../let/subject.md#one-liner-it-form).

## Validation errors

`define-matcher` rejects misuse up front:

| Mistake                              | Error                                                                          |
| ------------------------------------ | ------------------------------------------------------------------------------ |
| Missing `match` block                | `define-matcher '<name>': match block is required`                             |
| Unknown option key                   | `define-matcher '<name>': unknown option ':<key>' (allowed: match, ...)`       |
| Non-Callable value for any option    | `define-matcher '<name>': ':<key>' must be a Callable`                         |

## The registry

`BDD::Behave::Matcher::Custom::registry()` returns the singleton
`CustomMatcherRegistry`. It is mostly an implementation detail, but it exposes
a handful of useful methods:

| Method                | Purpose                                                              |
| --------------------- | -------------------------------------------------------------------- |
| `register($name, %c)` | Internal. Used by `define-matcher` to register a configuration hash. |
| `exists($name)`       | Does a matcher with this name exist?                                 |
| `lookup($name)`       | Return the raw config hash, or die if unknown.                       |
| `build($name, |c)`    | Construct a `DefinedMatcher` (this is what `matcher(...)` calls).    |
| `names()`             | All registered names, sorted.                                        |
| `clear()`             | Wipe the registry. Useful in tests that re-register a name.          |

Redefining a matcher with the same name *replaces* the previous registration;
previously returned factory closures pick up the new definition the next time
they are called.

## Putting it together

```raku
use BDD::Behave;
use BDD::Behave::Matcher;
use BDD::Behave::Matcher::Custom;

my &be-a-prime = define-matcher 'be-a-prime',
  match => -> $actual {
    return False if $actual < 2;
    return True  if $actual == 2;
    for 2..$actual.sqrt.Int -> $d {
      return False if $actual %% $d;
    }
    True;
  },
  failure-message =>
    -> $actual { "expected $actual to be prime" },
  failure-message-negated =>
    -> $actual { "expected $actual not to be prime" },
  description => -> { 'be prime' };

describe 'prime checks', {
  it 'recognises primes', {
    expect(7).to.be(be-a-prime());
    expect(7).to.be-a-prime;            # FALLBACK dispatch
  }

  it 'rejects composites', {
    expect(9).to.not.be(be-a-prime());
  }
}
```
