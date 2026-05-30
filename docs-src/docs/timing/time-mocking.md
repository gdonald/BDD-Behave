# Time Mocking

`BDD::Behave` ships with Timecop-style helpers for freezing and traveling
through time inside an example. They work by wrapping Raku's `now` term,
`DateTime.now`, and `Date.today` so the wrap consults a
dynamically-scoped freeze. When no freeze is active, the wrappers fall
through to the real time source — they have no effect outside a freeze block.

## `freeze-time`

```raku
freeze-time {
  # `now`, `DateTime.now`, and `Date.today` are all frozen
  # at the moment the block began.
  my $a = now;
  sleep 0.5;
  my $b = now;
  expect($a).to.eq($b);
};
```

Freeze at an explicit moment with a `DateTime`, `Instant`, or ISO 8601 string:

```raku
freeze-time DateTime.new('2024-01-01T00:00:00Z'), {
  expect(DateTime.now.year).to.eq(2024);
};

freeze-time '2030-06-15T12:00:00Z', {
  expect(DateTime.now.year).to.eq(2030);
};
```

`Date.today` is also frozen to the same instant:

```raku
freeze-time DateTime.new('2024-07-04T12:00:00Z'), {
  expect(Date.today.year).to.eq(2024);
  expect(Date.today.month).to.eq(7);
  expect(Date.today.day).to.eq(4);
};
```

## `travel-to`

`travel-to` is a synonym for the explicit-moment form of `freeze-time`:

```raku
travel-to DateTime.new('2026-03-15T00:00:00Z'), {
  expect(DateTime.now.year).to.eq(2026);
};
```

## `travel-by`

Inside an active freeze block, `travel-by` advances the frozen instant
forward by a `Duration` (or a plain `Real` number of seconds):

```raku
freeze-time DateTime.new('2024-01-01T00:00:00Z'), {
  expect(DateTime.now.hour).to.eq(0);

  travel-by(Duration.new(3600));

  expect(DateTime.now.hour).to.eq(1);
};
```

Multiple advances compose:

```raku
freeze-time $start, {
  travel-by(10);
  travel-by(20);
  travel-by(30);
  # frozen instant is now $start + 60 seconds
};
```

Calling `travel-by` outside an active freeze dies with a clear message.

## Nested freezes

Inner freezes shadow outer ones. When the inner block exits, the outer
freeze is restored:

```raku
freeze-time DateTime.new('2020-01-01T00:00:00Z'), {
  expect(DateTime.now.year).to.eq(2020);

  freeze-time DateTime.new('2030-06-15T00:00:00Z'), {
    expect(DateTime.now.year).to.eq(2030);
  };

  expect(DateTime.now.year).to.eq(2020);
};
```

## Restoration

Time is always restored when a freeze block exits, including when the block
throws. The frozen state never leaks to the next example.

## `:freeze-time` metadata

Examples and groups can opt into a freeze via the `:freeze-time` metadata.
The runner wraps the example body in a freeze around `before-each` /
`after-each` hooks — wall-clock duration is measured outside the freeze, so
the example's `started-at` / `finished-at` / `duration` accessors still
report real time.

Freeze at the moment the example body begins:

```raku
it 'freezes at start', :freeze-time, {
  my $a = now;
  sleep 0.1;
  my $b = now;
  expect($a).to.eq($b);
};
```

Freeze at an explicit moment:

```raku
it 'freezes at 2024-01-01', :freeze-time(DateTime.new('2024-01-01T00:00:00Z')), {
  expect(DateTime.now.year).to.eq(2024);
};
```

Pass `:freeze-time(False)` to explicitly opt out (useful when overriding an
inherited group-level freeze).

## `current-time`

`current-time` returns the current `Instant` — frozen when a freeze is
active, real `now` otherwise. Use it from helpers that want to read "time"
without bypassing the freeze.

```raku
freeze-time $instant, {
  expect(current-time()).to.eq($instant);
};
```
