# aggregate-failures

`aggregate-failures` groups one or more expectations into a labeled block. All expectations run to completion — a failure earlier in the block does not skip the rest — and failures recorded inside the block are tagged with the block's label in the failure summary.

In BDD::Behave, expectations already accumulate rather than stop at the first miss, so the main thing `aggregate-failures` adds is **labeling** and **exception trapping**: an exception thrown inside the block is captured and reported as a single labeled failure rather than aborting the example.

## Basic form

```raku
aggregate-failures 'validating response', {
  expect($response.status).to.be(200);
  expect($response.body).to.include('ok');
  expect($response.headers<Content-Type>).to.be('text/plain');
}
```

Each of the three expectations runs even if the first one fails. The failure summary marks each tagged failure with the label:

```
  [ ✗ ] specs/api-spec.raku:5 (aggregate: validating response)
        Expected: 500
        to be:    200
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
