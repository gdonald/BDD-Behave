# aggregate-failures

By default in BDD::Behave, the **first failing expectation inside an `it` body throws and aborts the rest of that example** — matching RSpec semantics. Ideally each `it` block contains exactly one `expect`. When you genuinely need multiple expectations in one `it` body, wrap them in `aggregate-failures { ... }`:

- All expectations inside the block run to completion (a failure earlier in the block does not skip the rest).
- The N inner failures are **rolled up into a single `Failure` row** at the line where the `aggregate-failures` block opens.
- That single row carries the block's label (when one is given) and renders the inner failures as a bulleted summary under its header.

This means the progress stream's `F` count and the number of rows in the `Failures:` section stay aligned — one failed `it` produces one `F` and one row, regardless of how many `expect`s misfired inside.

Exceptions thrown inside the block are also captured into the same rollup rather than propagating.

## Basic form

```raku
aggregate-failures 'validating response', {
  expect($response.status).to.be(200);
  expect($response.body).to.include('ok');
  expect($response.headers<Content-Type>).to.be('text/plain');
}
```

All three expectations run even if the first one fails. The failure summary shows one rollup row at the `aggregate-failures` line, with each inner failure as an indented bullet:

```
  [ ✗ ] specs/api-spec.raku:5 (aggregate: validating response)
      api validates response
      3 expectations failed inside aggregate-failures
        - specs/api-spec.raku:6:
            Expected: 500
            to be: 200
        - specs/api-spec.raku:7:
            Expected: 'oops'
            to be: 'ok'
        - specs/api-spec.raku:8:
            Expected: 'application/json'
            to be: 'text/plain'
```

## Forms

```raku
aggregate-failures { ... };                # no label
aggregate-failures 'my label', { ... };    # labeled
```

The labeled form takes a `Str:D` followed by a block. The unlabeled form takes just a block and inherits the surrounding `aggregate-failures` label, if any.

## Exception trapping

Any exception thrown inside the block is caught and converted to a failure tagged with the block's label. The exception does not propagate out of the block, and any expectations *before* the exception remain in the failure list:

```raku
aggregate-failures 'risky path', {
  expect($a).to.be(1);
  die 'something went wrong';   # captured as a labeled failure
  expect($b).to.be(2);          # not reached
}
```

The captured exception is rendered as `exception in aggregate-failures: <message>` in the failure summary.

## Nesting

Blocks may nest. Inner labels win for failures recorded inside the inner block; an unlabeled inner block inherits the outer label.

```raku
aggregate-failures 'outer', {
  aggregate-failures 'inner', {
    expect($x).to.be(1);   # tagged 'inner'
  }
  expect($y).to.be(2);     # tagged 'outer'
}

aggregate-failures 'outer', {
  aggregate-failures {
    expect($x).to.be(1);   # tagged 'outer' (inherited)
  }
}
```

## Failure metadata

`Failure.aggregation-label` carries the label string (or `Str` when no label applies). The label is set at `Failure` construction time from the dynamic variable `$*BEHAVE-AGGREGATION-LABEL`, so user-defined matchers that build their own `Failure` instances pick it up automatically.

## `capture-failures` for meta-tests

`capture-failures { ... }` is a sibling DSL function for tests that need to **inspect** the recorded `Failure` records without polluting the surrounding example:

```raku
my @captured = capture-failures {
  expect(0).to.be-between(1, 10);
};
expect(@captured.elems).to.be(1);
expect(@captured[0].message).to.include('between');
```

It runs the block with throw-on-failure suppressed (so multiple failing expectations all execute), returns the new `Failure` records as a `List`, and **splices them off** the global `Failures.list` so the surrounding example reports cleanly.

Unlike `aggregate-failures`, `capture-failures` does **not** roll up. Each inner failure is returned as its own `Failure` object so the meta-test can assert on individual entries.

Use it when writing a spec for a matcher's failure behavior. Use `aggregate-failures` when writing application code where you genuinely want multiple expectations to run in a single example body.

## Automatic aggregation

Three configuration options ask the runner to wrap each example's body in `aggregate-failures` semantics automatically — labeling its failures and converting an uncaught exception inside the example into a labeled failure rather than letting it short-circuit into the runner's error track.

### Per-example metadata

Attach `:aggregate-failures` to an `it` (or `fit`/`xit`) call:

```raku
it 'validates response', :aggregate-failures, {
  expect($response.status).to.be(200);
  expect($response.body).to.include('ok');
}

it 'validates response', :aggregate-failures<api>, {
  expect($response.status).to.be(200);
  expect($response.body).to.include('ok');
}
```

The `True` form turns auto-aggregation on with no label. A `Str` form (`:aggregate-failures<api>`) labels every failure recorded by that example with the given string.

### Per-group metadata

Attaching the metadata to a `describe` or `context` cascades to every example beneath it:

```raku
describe 'API responses', :aggregate-failures<api>, {
  it 'is JSON',     { expect($response.content-type).to.include('json') }
  it 'has data',    { expect($response.body).to.include('"data"') }
  it 'is well-formed', { expect({ from-json($response.body) }).not.to.raise-error }
}
```

A leaf `it` may override an outer group with its own metadata — including `:aggregate-failures(False)` to opt out:

```raku
describe 'API responses', :aggregate-failures, {
  it 'with raw control', :aggregate-failures(False), { ... }
}
```

### Runner-level default and CLI flag

`Runner` accepts an `:aggregate-failures` attribute that applies to every example unless overridden by metadata:

```raku
BDD::Behave::Runner::Runner.new(:aggregate-failures);            # on, no label
BDD::Behave::Runner::Runner.new(:aggregate-failures<global>);    # on, label 'global'
```

`bin/behave` exposes the same switch on the command line:

```
behave --aggregate-failures               # on, no label
behave --aggregate-failures=global        # on, label 'global'
```

### Resolution rules

When deciding whether to auto-aggregate an example, the runner walks the ancestry leaf-to-root and uses the first **defined** value of the `aggregate-failures` metadata, falling back to the runner default. `False` is a defined value, so an inner `:aggregate-failures(False)` overrides an outer truthy ancestor. An empty-string label is treated as off.

### Interaction with explicit `aggregate-failures` blocks

An explicit `aggregate-failures 'inner', { ... }` block inside an auto-aggregated example takes precedence inside the block — its label tags failures recorded there, and unlabeled inner blocks inherit the auto label. Failures recorded before or after the inner block continue to use the example's auto label.

### Exception handling

When auto-aggregation is on, an exception raised by the example body is converted into a single labeled `Failure` whose message begins with `exception in <full nested description>:` followed by the original exception text. With auto-aggregation off, the existing behavior is preserved: the runner stores the exception in its error track.
