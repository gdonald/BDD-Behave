# Diff Output

When an expectation fails, BDD::Behave produces a structured, colorized diff between the actual and expected values whenever both are of a "diffable" shape. The diff is shape-aware: strings are compared character-by-character (single line) or line-by-line (multi line); arrays, hashes, sets, bags, and mixes are rendered as multi-line JSON-style structures and compared with a longest-common-subsequence algorithm.

## Conventions

* Lines marked with red `-` are values that were *expected* but not present in the actual.
* Lines marked with green `+` are values that were *received* but not in the expected.
* Unmarked lines are unchanged context.

This matches the `--Expected` / `++Received` convention used by Jest and similar runners.

## When a diff is produced

A diff is rendered when both values share one of these shapes:

| Shape  | Trigger                                  |
|--------|------------------------------------------|
| `Str`  | both values are `Str`                    |
| `Array`| both do `Positional`                     |
| `Hash` | both do `Associative`                    |
| `Set`  | both are `Set` or `SetHash`              |
| `Bag`  | both are `Bag` or `BagHash`              |
| `Mix`  | both are `Mix` or `MixHash`              |
| `Junction` | expected is any `Junction` (`any`/`all`/`one`/`none`) |

Plain scalars (`Int`, `Bool`, `Rat`, etc.) keep the existing `Expected:` / `to be:` lines without a diff section, since the two `.raku` representations already make the difference obvious.

## String diffs

For single-line strings, the differing region is highlighted in place using common prefix/suffix detection:

```
- 'hello earth'
+ 'hello world'
```

The non-matching characters (`earth` and `world`) are colorized red and green respectively.

For multi-line strings, the diff drops to line-level:

```
  foo
- QUX
+ bar
  baz
```

## Structural diffs

Hashes, arrays, sets, bags, and mixes are pretty-printed in JSON-style and then compared line-by-line:

```
  {
    "name" => "alice",
-   "age" => 31,
+   "age" => 30,
    "city" => "paris",
  }
```

Hash keys are sorted alphabetically for stable, reviewable output. Nested structures recurse and preserve indentation:

```
  {
    "tags" => [
      "x",
-     "z",
+     "y",
    ],
    "user" => {
      "age" => 30,
-     "name" => "bob",
+     "name" => "alice",
    },
  }
```

## Junction diffs

When the expected value is a `Junction`, the diff collapses it to its constituent eigenstates and marks each one with `✓` (smartmatched the given value) or `✗` (didn't), so the reader sees exactly which alternatives didn't line up:

```
- any(1, 2, 3)
+ 5
  Alternatives (none of 3 matched; expected at least one):
    ✗ 1
    ✗ 2
    ✗ 3
```

The summary line is tailored per junction kind (`any` / `all` / `one` / `none`) and reflects the negation state when `.not` is in play. Type-object alternatives (`Int | Rat`) render by name; values render via `.raku`. See [Junctions](../expectations/junctions.md) for the full set of summaries and an example under each kind.

Junction diffs are emitted even under negation (unlike scalar diffs), because the failed-negation case for a junction is still informative: the reader wants to see *which* alternative the given value collided with.

## Negated expectations

`expect(...).not.to.be(...)` failures don't render a diff: when the comparison was supposed to *fail* and didn't, both values match exactly, so a diff would be empty. The standard `Expected:` / `not to be:` lines are sufficient. The exception is junction expectations under negation — see [Junction diffs](#junction-diffs) above.

## Module surface

The diff machinery lives in `BDD::Behave::Diff`. The exported functions are:

* `diff-shape($value --> Str)` — `'Str'`, `'Array'`, `'Hash'`, `'Set'`, `'Bag'`, `'Mix'`, `'Scalar'`, or `'Undef'`.
* `diffable($given, $expected --> Bool)` — `True` when both values share a structural shape worth diffing or `$expected` is a `Junction`.
* `render-diff($given, $expected, Bool :$negated --> Str)` — produces the colorized diff string. Always returns a single string (multi-line for structural and junction diffs). `:negated` only affects junction summaries.
* `pretty-lines($value, :$indent --> List)` — exposes the underlying pretty-printer for advanced use.
* `is-junction($value --> Bool)` — `True` for any `Junction` (uses a typed multi to avoid autothreading).
* `junction-kind(Junction:D --> Str)` — `'any'`, `'all'`, `'one'`, or `'none'`.
* `junction-eigenstates(Junction:D --> List)` — the alternatives the junction was built from.

You normally don't need to call these directly; failure output uses them automatically.
