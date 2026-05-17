use BDD::Behave::Colors;
use BDD::Behave::Failures;
use BDD::Behave::Formatter;

unit class BDD::Behave::Formatter::Default does BDD::Behave::Formatter;

has Int $!indent = 0;

method name(--> Str) { 'default' }

method print-indent {
  print '  ' x $!indent;
}

method suite-loading(Str :$file) {
  say "\nLoading: $file";
}

method suite-start($suite, Bool :$multi-file = False) {
  return unless $multi-file;
  say "\n" ~ light-blue($suite.file.basename);
}

method group-start($group) {
  self.print-indent;
  say "⮑  '{$group.description}'";
  $!indent++;
}

method group-end($group) {
  $!indent--;
}

method group-around-skipped($group) {
  self.print-indent;
  say light-blue("⮑  SKIPPED (around-all did not invoke continuation)");
}

method example-start($example, Bool :$auto = False) {
  return if $auto;
  self.print-indent;
  say "⮑  '{$example.description}'";
}

method example-auto-description($example, Str :$description) {
  self.print-indent;
  say "⮑  '{$description}'";
}

method example-pass($example) {
  self.print-indent;
  say green("  ⮑  SUCCESS");
}

method example-fail($example, :$failure-info) {
  self.print-indent;
  say red("  ⮑  FAILURE");
}

method example-pending($example) {
  self.print-indent;
  say light-blue("⮑  '{$example.description}'");
  self.print-indent;
  say light-blue("  ⮑  PENDING");
}

method example-skipped($example) {
  self.print-indent;
  say light-blue("⮑  '{$example.description}'");
  self.print-indent;
  say light-blue("  ⮑  SKIPPED");
}

method example-around-skipped($example) {
  self.print-indent;
  say light-blue("⮑  '{$example.description}'");
  self.print-indent;
  say light-blue("  ⮑  SKIPPED (around-each did not invoke continuation)");
}

method example-slow($example, Real :$threshold) {
  self.print-indent;
  say yellow(sprintf '  ⮑  SLOW (%.3fs, threshold %.3fs)',
                     $example.duration, $threshold);
}

method example-memory-leak($example, Int :$threshold) {
  self.print-indent;
  say yellow(sprintf '  ⮑  MEMORY (Δ%d KB, threshold %d KB)',
                     $example.memory-delta, $threshold);
}

method run-summary(
  $result,
  Bool :$aborted   = False,
  Int  :$fail-fast = 0,
  Str  :$order     = 'defined',
  Int  :$seed,
) {
  say '';

  Failures.say;

  my $total-msg   = "{$result.total} example" ~ ($result.total == 1 ?? '' !! 's');
  my $failed-msg  = $result.failed  > 0 ?? red("{$result.failed} failed")             !! '';
  my $pending-msg = $result.pending > 0 ?? light-blue("{$result.pending} pending")    !! '';
  my $skipped-msg = $result.skipped > 0 ?? light-blue("{$result.skipped} skipped")    !! '';
  my $passed-msg  = $result.passed  > 0 ?? green("{$result.passed} passed")           !! '';

  my @parts = ($total-msg, $failed-msg, $pending-msg, $skipped-msg, $passed-msg).grep(*.so);
  say @parts.join(', ');

  if $aborted {
    my $word = $fail-fast == 1 ?? 'failure' !! 'failures';
    say red("Aborted after $fail-fast $word (--fail-fast)");
  }

  if $order eq 'random' && $seed.defined {
    say "Randomized with seed $seed";
  }
}

method profile-summary(@records, Int :$limit) {
  return unless $limit > 0;
  return unless @records.elems;

  my @sorted = @records.sort({ -$^a<duration> });
  my @top    = @sorted[0 ..^ ($limit min @sorted.elems)];

  my $total = @top.map(*<duration>).sum;
  my $shown = @top.elems;
  say '';
  say "Top $shown slowest example" ~ ($shown == 1 ?? '' !! 's')
      ~ " ({sprintf '%.3f', $total}s total):";

  for @top -> $rec {
    my $ex  = $rec<example>;
    my $loc = $ex.defined ?? "{$ex.file}:{$ex.line}" !! '';
    say sprintf '  %.3fs  %s', $rec<duration>, $rec<description>;
    say "          $loc" if $loc.chars;
  }
}

method memory-profile-summary(@records, Int :$limit) {
  return unless $limit > 0;
  return unless @records.elems;

  my @sorted = @records.sort({ -$^a<delta> });
  my @top    = @sorted[0 ..^ ($limit min @sorted.elems)];

  my $total = @top.map(*<delta>).sum;
  my $shown = @top.elems;
  say '';
  say "Top $shown memory-heaviest example" ~ ($shown == 1 ?? '' !! 's')
      ~ " ({$total} KB total Δ):";

  for @top -> $rec {
    my $ex  = $rec<example>;
    my $loc = $ex.defined ?? "{$ex.file}:{$ex.line}" !! '';
    say sprintf '  %+d KB  %s', $rec<delta>, $rec<description>;
    say "          $loc" if $loc.chars;
  }
}

method benchmark-summary-section(
  @summaries, @regressions,
  Real     :$threshold,
  Str      :$format,
  IO::Path :$output,
  :$runner,
) {
  return unless @summaries.elems;
  my $rendered = $runner.render-benchmark-output(
    @summaries, @regressions,
    :$threshold, :$format,
  );
  if $output.defined {
    $output.spurt: $rendered ~ "\n";
  } else {
    say '';
    print $rendered;
    say '' unless $rendered.ends-with("\n");
  }
}

method multi-file-overall(
  $result,
  Str :$order = 'defined',
  Int :$seed,
) {
  say "\n" ~ "=" x 60;
  say "Overall: {$result.total} example" ~ ($result.total == 1 ?? '' !! 's');
  say red("  {$result.failed} failed")           if $result.failed  > 0;
  say light-blue("  {$result.pending} pending")  if $result.pending > 0;
  say light-blue("  {$result.skipped} skipped")  if $result.skipped > 0;
  say green("  {$result.passed} passed")         if $result.passed  > 0;
  say "Randomized with seed $seed" if $order eq 'random';
}

method multi-file-profile($runner, @records, Int :$limit) {
  self.profile-summary(@records, :$limit);
}

method multi-file-memory-profile($runner, @records, Int :$limit) {
  self.memory-profile-summary(@records, :$limit);
}

method multi-file-benchmark(
  $runner,
  @summaries, @regressions,
  Real     :$threshold,
  Str      :$format,
  IO::Path :$output,
) {
  self.benchmark-summary-section(
    @summaries, @regressions,
    :$threshold, :$format, :$output, :$runner,
  );
}

method load-errors(@errors) {
  return unless @errors.elems;
  say "\n" ~ red("Load errors ({@errors.elems}):");
  for @errors -> $err {
    say red("  ✗ ") ~ $err<file>;
    for $err<message>.lines -> $line {
      say "      $line";
    }
  }
}
