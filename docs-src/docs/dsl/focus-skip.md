# Focus and Skip

Behave provides DSL helpers for skipping examples that should not run and for focusing on a subset of examples while iterating on a feature. They behave like the corresponding helpers in RSpec.

## Skipping examples

Use `xit` to register an example that should be reported but never executed. Its body is registered but never invoked.

```raku
describe 'Order', {
  it  'totals correctly', { ... }
  xit 'pending refactor', { ... }   # appears as SKIPPED, body never runs
}
```

Use `xdescribe` (or `xcontext`) to skip every example inside a group, including nested groups:

```raku
xdescribe 'Email delivery', {
  it 'sends the welcome email', { ... }
  it 'queues the digest',       { ... }   # both reported as SKIPPED
}
```

`before-all`, `after-all`, `before-each`, and `after-each` hooks are not run for examples inside a skipped group.

## Focusing examples

Use `fit` to mark a single example as focused, and `fdescribe` (or `fcontext`) to focus an entire group. When any focused example or group exists in a suite, **only focused examples run**; non-focused examples are silently filtered out.

```raku
describe 'User', {
  it  'persists the email',          { ... }   # filtered out
  fit 'sends a welcome email',       { ... }   # runs
  it  'enqueues the digest worker',  { ... }   # filtered out
}
```

`fdescribe` focuses every example in the group, including nested groups. Sibling groups in the same file are filtered out:

```raku
fdescribe 'OrderRefund', {
  it 'refunds the captured amount', { ... }   # runs
  it 'updates the audit log',       { ... }   # runs
}

describe 'OrderShipment', {
  it 'creates a shipping label', { ... }   # filtered out by focus mode
}
```

Focus mode is detected per suite (per spec file). Files without any `fit`/`fdescribe` continue to run every example as usual.

## Combining focus and skip

Skipped examples are still reported as `SKIPPED` even when focus mode is on. A `fit` inside an `xdescribe` stays skipped — skip wins over focus.

```raku
fdescribe 'Account', {
  it  'creates an account',     { ... }   # focused, runs
  xit 'closes pending account', { ... }   # focused-by-inheritance, but skipped
}

xdescribe 'Legacy importer', {
  fit 'imports a CSV', { ... }   # still SKIPPED — skip wins over focus
}
```

## Combining with tag filters

Focus and tag filtering compose. An example must match the tag filters **and** be focused (when focus mode is on) to run.

```shell
$ behave --tag fast               # tag filter alone
$ behave specs/users-spec.raku    # if the file has fit, only focused examples run
```

## Output and counts

Skipped examples display in light blue with a `SKIPPED` marker. The summary line includes a `skipped` count alongside `passed`, `failed`, and `pending`:

```
9 examples, 6 skipped, 3 passed
```

Exit code stays `0` when only skips are present; only failures cause a non-zero exit.

## Inspecting focus / skip programmatically

Each `Example` and `ExampleGroup` exposes:

- `.focused` — `True` if the node was registered with `fit` / `fdescribe` / `:focused`.
- `.skipped` — `True` if the node was registered with `xit` / `xdescribe` / `:skipped`.
- `.effective-focused` — `True` if the node or any ancestor is focused.
- `.effective-skipped` — `True` if the node or any ancestor is skipped.

These mirror the `tags` / `effective-tags` helpers and are useful for custom reporters or tooling.
