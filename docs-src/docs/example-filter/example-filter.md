# Filtering examples by description

`--example PATTERN` (alias `-e PATTERN`) runs only examples whose **full nested description** matches `PATTERN`. The full nested description joins every enclosing `describe` / `context` description with the `it` description, separated by spaces:

```raku
describe 'User signup', {
  context 'with a referral code', {
    it 'awards bonus credits', { ... }
    # Full description: "User signup with a referral code awards bonus credits"
  }
}
```

## Substring matching (default)

By default `PATTERN` is a plain substring:

```shell
$ behave --example 'User signup'        # every example under User signup
$ behave -e 'awards bonus'              # the single example
```

The pattern matches when it appears anywhere inside the full nested description.

## Regex matching

Wrap `PATTERN` in `/.../` to compile it as a Raku regex. Standard Raku regex rules apply, so whitespace is not significant. Use `\s` (or quote literal text) for spaces:

```shell
$ behave --example '/\d+/'              # examples whose description has a digit
$ behave --example '/User\s+signup/'    # User-signup-related examples via regex
```

## Multiple patterns (OR)

Repeat the flag for OR semantics:

```shell
$ behave --example 'User signup' --example 'Order checkout'
```

An example runs if it matches **any** pattern.

## Combining with tags

`--example` composes with `--tag`, `--exclude-tag`, and focus mode using AND semantics: an example must satisfy every active filter to run:

```shell
$ behave --example 'User signup' --tag fast        # signup AND fast
$ behave --example 'User signup' --exclude-tag flaky
```

## Group hooks

Groups whose subtrees contain no matching examples are skipped, including their `before-all` / `after-all` / `around-all` hooks. This avoids running expensive group setup when nothing inside the group will execute.

## No matches is success

If a pattern matches nothing, `behave` reports zero total examples and exits `0`:

```
$ behave --example 'no-such-thing'
0 examples
```

This makes it safe to drop `--example` filters into CI matrix builds without worrying about tripping a "zero tests" failure for legitimately empty selections.

## See also

- [Tags](../tags/tags.md): tag-based filtering with `--tag` / `--exclude-tag`
- [Focus and Skip](../focus-skip/focus-skip.md): `fit` / `xit` / `fdescribe` / `xdescribe`
- [Running Specs](../running.md): full CLI reference
