# Composable Matchers

Combine matchers with `.and` and `.or` to express compound expectations
without writing a one-off custom matcher. Every type that does the
[Matcher](matchers.md) role gets these two methods automatically — so they
work with built-in matchers, hand-rolled `does Matcher` classes, and
[`define-matcher`](custom-matchers.md) factories alike.

## `.and`

`AndMatcher` requires *every* inner matcher to pass. It short-circuits at the
first failure and reports which inner matcher rejected the value.

```raku
use BDD::Behave;
use BDD::Behave::Matcher::Core;
use BDD::Behave::Matcher::Numeric;

it 'is a small positive integer', {
  my $small-positive = BeMatcher.new(:expected(Int))
    .and(BeGreaterThanMatcher.new(:expected(0)))
    .and(BeLessThanMatcher.new(:expected(100)));

  expect(50).to.be($small-positive);       # passes
  expect(200).to.not.be($small-positive);  # passes
}
```

Pass multiple matchers to a single `.and` call to combine them in one step:

```raku
BeMatcher.new(:expected(Int)).and(
  BeGreaterThanMatcher.new(:expected(0)),
  BeLessThanMatcher.new(:expected(100)),
);
```

Chained `.and` calls flatten into a single `AndMatcher`, so the failure
message and `description` stay readable regardless of how many you compose.

## `.or`

`OrMatcher` passes when *any* inner matcher passes. It short-circuits at the
first match and reports `matched-index` for tooling.

```raku
my $endpoint-ish = StartWithMatcher.new(:expected(['/api/']))
  .or(StartWithMatcher.new(:expected(['/v2/'])));

expect('/api/users').to.be($endpoint-ish);   # passes
expect('/v2/items').to.be($endpoint-ish);    # passes
expect('/admin').to.not.be($endpoint-ish);   # passes
```

As with `.and`, multiple-arg calls and chained calls both flatten.

## Composing with custom matchers

`define-matcher` factories return ordinary matchers, so they compose
the same way:

```raku
my &positive = define-matcher 'positive', match => -> $a { $a > 0 };
my &small    = define-matcher 'small',    match => -> $a { $a < 100 };

expect(50).to.be(positive().and(small()));     # passes
expect(200).to.not.be(positive().and(small())); # passes
```

## Mixing `.and` and `.or`

Composition is left-associative: each call returns a new composite, so
chains build up naturally.

```raku
# (A and B) or C
$a.and($b).or($c);

# A and (B or C)  — group with an explicit inner composite
$a.and($b.or($c));
```

Reach for an explicit nested matcher when precedence matters.

## Negation

`.not` flips the composite result the same way it flips any other matcher:

| Composite        | Under `.not` passes when…                |
| ---------------- | ---------------------------------------- |
| `AndMatcher`     | At least one inner matcher fails         |
| `OrMatcher`      | Every inner matcher fails                |

Failure messages for the negated forms tell you why the composite ended up
matching when it wasn't supposed to (which `AndMatcher` couldn't escape, or
which `OrMatcher` branch matched).

## Failure messages

`AndMatcher` failure messages identify the first inner matcher that
rejected the value:

```
expected 200 to be greater than 0 and be less than 100, but be less than 100 failed: expected 200 to be less than 100
```

`OrMatcher` failure messages list every inner matcher and note that none
matched:

```
expected 7 to be 5 or be 10, but none matched
```

Negated `AndMatcher` and `OrMatcher` failure messages mirror the structure
above with `not to …`.

## Inspecting composites

Both composites expose useful state for diagnostics and custom formatters:

| Method                              | Returns                                                |
| ----------------------------------- | ------------------------------------------------------ |
| `.matchers`                         | The flattened inner matcher list.                      |
| `AndMatcher.failing-index`          | Index of the first inner matcher that failed (or `Int`).|
| `AndMatcher.failing-matcher`        | The first inner matcher that failed (or `Nil`).        |
| `OrMatcher.matched-index`           | Index of the first inner matcher that matched.         |
| `OrMatcher.matched-matcher`         | The first inner matcher that matched.                  |
| `.expected-value`                   | A `List` of every inner matcher's `expected-value`.    |
| `.description`                      | Inner descriptions joined with ` and ` / ` or `.       |

## Argument validation

`.and` and `.or` accept only objects that do the `Matcher` role. Passing
anything else dies immediately with a clear message — composition catches
typos at the call site rather than papering over them with surprising
smartmatch semantics.
