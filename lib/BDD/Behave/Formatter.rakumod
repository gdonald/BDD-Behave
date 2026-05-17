unit role BDD::Behave::Formatter;

method name(--> Str) { 'formatter' }

method suite-loading(Str :$file)                               { }
method suite-start($suite, Bool :$multi-file = False)          { }
method suite-end($suite)                                       { }

method group-start($group)            { }
method group-end($group)              { }
method group-around-skipped($group)   { }

method example-start($example, Bool :$auto = False)              { }
method example-auto-description($example, Str :$description)     { }
method example-pass($example)                                    { }
method example-fail($example, :$failure-info)                    { }
method example-pending($example)                                 { }
method example-skipped($example)                                 { }
method example-around-skipped($example)                          { }
method example-slow($example, Real :$threshold)                  { }
method example-memory-leak($example, Int :$threshold)            { }

method run-summary(
  $result,
  Bool     :$aborted   = False,
  Int      :$fail-fast = 0,
  Str      :$order     = 'defined',
  Int      :$seed,
) { }

method profile-summary(@records, Int :$limit)                    { }
method memory-profile-summary(@records, Int :$limit)             { }

method benchmark-summary-section(
  @summaries, @regressions,
  Real     :$threshold,
  Str      :$format,
  IO::Path :$output,
  :$runner,
) { }

method multi-file-overall(
  $result,
  Str :$order = 'defined',
  Int :$seed,
) { }

method multi-file-profile($runner, @records, Int :$limit)        { }
method multi-file-memory-profile($runner, @records, Int :$limit) { }
method multi-file-benchmark(
  $runner,
  @summaries, @regressions,
  Real     :$threshold,
  Str      :$format,
  IO::Path :$output,
) { }

method load-errors(@errors) { }
