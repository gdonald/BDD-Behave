# Junctions

`expect(actual).to.be(expected)` uses Raku smartmatch (`~~`) through the built-in `BeMatcher`. Junctions on the right-hand side of a smartmatch auto-thread, so every junction form composes with `expect` without any extra DSL.

## `any`: match any one alternative

```raku
expect($x).to.be(1 | 2 | 3);
expect($x).to.be(any(1, 2, 3));      # equivalent
```

Passes when `$x` smartmatches at least one of the alternatives.

```raku
expect($status).to.be('green' | 'yellow' | 'red');
expect($value).to.be(Int | Str);     # type-object alternatives
```

## `all`: match every alternative

```raku
expect($x).to.be(Int & Numeric);
expect($x).to.be(all(Int, Numeric)); # equivalent
```

Passes when `$x` smartmatches every alternative. Mixing distinct literal values (`1 & 2`) is effectively unsatisfiable because a single value cannot equal two different literals. Combine `all` with type checks, ranges, or predicates instead.

```raku
my subset Positive of Int where * > 0;
expect($x).to.be(Int & Positive);
```

## `one`: match exactly one alternative

```raku
expect($x).to.be(1 ^ 2 ^ 3);
expect($x).to.be(one(1, 2, 3));      # equivalent
```

Passes when exactly one alternative matches. Useful for mutually exclusive states.

## `none`: match no alternative

```raku
expect($x).to.be(none(1, 2, 3));
```

Passes when `$x` matches none of the listed values.

## Negation

`.not` flips the outer result. The junction collapses to a `Bool` first, then `.not` negates it:

```raku
expect(5).to.not.be(1 | 2 | 3);      # passes: 5 is not in the set
expect(2).to.not.be(none(1, 2, 3));  # passes: 2 is in the set
```

## Failure metadata

When a junction expectation fails, `Failure.expected` carries the `Junction` itself and `Failure.given` carries the actual value:

```raku
expect(5).to.be(1 | 2 | 3);
# Failure.given    == 5
# Failure.expected == any(1, 2, 3)
```

## Junction-aware diffs

When a junction expectation fails, the `Diff:` section collapses the junction to its constituent alternatives, marking each with `✓` (matched) or `✗` (didn't match), so the reader sees exactly which alternatives didn't line up with the given value:

```
Expected: 5
to be: any(1, 2, 3)
Diff:
  - any(1, 2, 3)
  + 5
    Alternatives (none of 3 matched; expected at least one):
      ✗ 1
      ✗ 2
      ✗ 3
```

Each junction kind reports its own summary line:

- `any`: `none of N matched; expected at least one`
- `all`: `K of N matched; expected all`
- `one`: `K of N matched; expected exactly one`
- `none`: `K of N matched; expected zero`

Under `.not`, the summary phrases the inverted intent (e.g. `expected none under negation` for negated `any`, `expected at least one under negation` for negated `none`), so the diff stays useful when the matcher fires through negation.

Type-object alternatives (`Int | Rat`) render by name. Values render via `.raku`.

## See also

- [Matchers](matchers.md): the matcher role and built-ins.
- [Diff Output](../diff/diff.md): how the `Diff:` section is constructed for non-junction shapes.
- [Composable Matchers](composable-matchers.md): `.and` / `.or` on `Matcher` objects (object-level alternative to Raku's literal junctions).
