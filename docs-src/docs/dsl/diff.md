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

## Negated expectations

`expect(...).not.to.be(...)` failures don't render a diff: when the comparison was supposed to *fail* and didn't, both values match exactly, so a diff would be empty. The standard `Expected:` / `not to be:` lines are sufficient.

## Module surface

The diff machinery lives in `BDD::Behave::Diff`. The exported functions are:

* `diff-shape($value --> Str)` — `'Str'`, `'Array'`, `'Hash'`, `'Set'`, `'Bag'`, `'Mix'`, `'Scalar'`, or `'Undef'`.
* `diffable($given, $expected --> Bool)` — `True` when both values share a structural shape worth diffing.
* `render-diff($given, $expected --> Str)` — produces the colorized diff string. Always returns a single string (multi-line for structural diffs).
* `pretty-lines($value, :$indent --> List)` — exposes the underlying pretty-printer for advanced use.

You normally don't need to call these directly; failure output uses them automatically.
