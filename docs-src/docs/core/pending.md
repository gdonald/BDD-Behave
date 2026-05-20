# pending

`pending` marks an example as not yet implemented and records a human-readable reason. The example is registered, counted, and reported under the `PENDING` bucket in the runner output, but its body is **not** executed.

```raku
describe 'PaymentProcessor', {
  pending 'refunds — needs integration with the new gateway', {
    expect(processor.refund(100)).to.be-a(Refund);
  }
}
```

The runner output for the above renders the description in blue and prints `⮑  PENDING` underneath, and the final summary includes a `N pending` count alongside passes and failures.

## Forms

`pending` has two forms:

```raku
pending 'reason', { ... }   # reason + placeholder block (block not executed)
pending 'reason';           # reason only, no block
```

Both forms accept the same metadata keys as `it` (`:tag`, `:tags`, arbitrary `:meta`):

```raku
pending 'rewrite once we drop Raku 6.c', :tag<tech-debt>, {
  expect(legacy-api()).to.be(deprecated);
}
```

## `pending` vs `xit`

`pending` and `xit` both prevent the block from running, but they convey different intent and report under different buckets:

| | block runs? | bucket | when to use |
|---|---|---|---|
| `xit` | no | `SKIPPED` | tests temporarily not relevant (broken fixture, env mismatch) |
| `pending` | no | `PENDING` | functionality not yet implemented, with a written reason |

If you have functionality that *should* eventually work and you want a reminder, use `pending`. If you have a test that's noise or wrong for the current run, use `xit`.

## Reading the reason

The reason is stored on the example as both the description and as `pending-reason` metadata:

```raku
my $ex = registry().suites[0].groups[0].examples[0];
say $ex.description;                       # "rewrite once we drop Raku 6.c"
say $ex.get-metadata('pending-reason');    # "rewrite once we drop Raku 6.c"
```

Tools that walk the spec tree can use the `pending-reason` metadata key to surface a TODO list of unfinished work alongside ordinary test results.
