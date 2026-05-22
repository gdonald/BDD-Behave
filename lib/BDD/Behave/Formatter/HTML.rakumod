use BDD::Behave::Failures;
use BDD::Behave::Formatter;

unit class BDD::Behave::Formatter::HTML does BDD::Behave::Formatter;

has @!fragments;
has Bool $!multi-file = False;
has Bool $!emitted    = False;
has Int  $!failure-watermark = 0;
has Str  $!pending-auto-description;
has Real $!started-at;

method name(--> Str) { 'html' }

method suite-loading(Str :$file) { }

method suite-start($suite, Bool :$multi-file = False) {
  $!multi-file = $multi-file;
  $!started-at //= now.Real;
  if $multi-file {
    my $file = $suite.file.basename;
    @!fragments.push: '<h2 class="suite-file">' ~ self!escape($file) ~ '</h2>';
  }
}

method suite-end($suite) { }

method group-start($group) {
  @!fragments.push: '<details open class="group">'
                  ~ '<summary class="group-summary">'
                  ~ self!escape($group.description)
                  ~ '</summary>'
                  ~ '<div class="group-body">';
}

method group-end($group) {
  @!fragments.push: '</div></details>';
}

method group-around-skipped($group) {
  @!fragments.push: '<div class="example skipped">'
                  ~ '<span class="marker">⊘</span> '
                  ~ '<span class="desc">(group skipped: around-all did not invoke continuation)</span>'
                  ~ '</div>';
}

method example-start($example, Bool :$auto = False) {
  $!failure-watermark = Failures.list.elems;
  $!pending-auto-description = Str;
}

method example-auto-description($example, Str :$description) {
  $!pending-auto-description = $description;
}

method !escape(Str $s --> Str) {
  return '' unless $s.defined;
  my $r = $s;
  $r = $r.subst('&', '&amp;', :g);
  $r = $r.subst('<', '&lt;',  :g);
  $r = $r.subst('>', '&gt;',  :g);
  $r = $r.subst('"', '&quot;',:g);
  $r;
}

method !location($example --> Str) {
  '<span class="location">'
  ~ self!escape("{$example.file}:{$example.line}")
  ~ '</span>';
}

method !duration-span($example --> Str) {
  return '' unless $example.duration.defined;
  '<span class="duration">'
  ~ sprintf('%.3fs', $example.duration)
  ~ '</span>';
}

method !render-example($example, Str $status, Str $marker, Str :$detail) {
  my $description = $!pending-auto-description // $example.description;
  my $body = '<div class="example ' ~ $status ~ '">'
           ~ '<span class="marker">' ~ $marker ~ '</span> '
           ~ '<span class="desc">' ~ self!escape($description) ~ '</span> '
           ~ self!duration-span($example)
           ~ ' ' ~ self!location($example);
  $body ~= '<pre class="failure-detail">' ~ self!escape($detail) ~ '</pre>'
    if $detail.defined && $detail.chars;
  $body ~= '</div>';
  @!fragments.push: $body;
}

method example-pass($example) {
  self!render-example($example, 'pass', '✓');
  $!pending-auto-description = Str;
}

method example-fail($example, :$failure-info) {
  my @lines;
  if $failure-info.defined && $failure-info<exception>.defined {
    @lines.push: 'Exception: ' ~ $failure-info<exception>.message;
  }
  my $count = Failures.list.elems;
  if $count > $!failure-watermark {
    for Failures.list[$!failure-watermark .. $count - 1] -> $f {
      next if $f.from-runner-exception;
      @lines.push: "{$f.file}:{$f.line}";
      if $f.message.defined {
        @lines.push: "  $_" for $f.message.lines;
      } else {
        my $op = $f.negated ?? 'not to be' !! 'to be';
        @lines.push: "  Expected: {$f.given.gist}";
        @lines.push: "  $op:     {$f.expected.gist}";
      }
    }
  }
  self!render-example($example, 'fail', '✗', :detail(@lines.join("\n")));
  $!pending-auto-description = Str;
}

method example-pending($example) {
  my $reason = $example.get-metadata('pending-reason') // 'pending';
  self!render-example($example, 'pending', '⏸',
                      :detail("pending: $reason"));
}

method example-skipped($example) {
  self!render-example($example, 'skipped', '⊘');
}

method example-around-skipped($example) {
  self!render-example($example, 'skipped', '⊘',
                      :detail('around-each did not invoke continuation'));
}

method example-slow($example, Real :$threshold) { }
method example-memory-leak($example, Int :$threshold) { }

method run-summary(
  $result,
  Bool :$aborted   = False,
  Int  :$fail-fast = 0,
  Str  :$order     = 'defined',
  Int  :$seed,
) {
  return if $!multi-file;
  self!emit($result, :$aborted, :$order, :$seed);
}

method profile-summary(@records, Int :$limit)        { }
method memory-profile-summary(@records, Int :$limit) { }

method benchmark-summary-section(
  @summaries, @regressions,
  Real     :$threshold,
  Str      :$format,
  IO::Path :$output,
  :$runner,
) { }

method multi-file-overall($result, Str :$order = 'defined', Int :$seed) {
  self!emit($result, :$order, :$seed);
}

method multi-file-profile($runner, @records, Int :$limit)        { }
method multi-file-memory-profile($runner, @records, Int :$limit) { }
method multi-file-benchmark(
  $runner,
  @summaries, @regressions,
  Real     :$threshold,
  Str      :$format,
  IO::Path :$output,
) { }

method load-errors(@errors) {
  for @errors -> $err {
    my $file    = ($err<file>    // '').Str;
    my $message = ($err<message> // '').Str;
    @!fragments.push: '<div class="load-error">'
                    ~ '<strong>Load error in ' ~ self!escape($file) ~ '</strong>'
                    ~ '<pre>' ~ self!escape($message) ~ '</pre>'
                    ~ '</div>';
  }
}

method !summary-line($result --> Str) {
  my @parts;
  @parts.push: "{$result.total} example" ~ ($result.total == 1 ?? '' !! 's');
  @parts.push: "{$result.failed} failed"   if $result.failed  > 0;
  @parts.push: "{$result.pending} pending" if $result.pending > 0;
  @parts.push: "{$result.skipped} skipped" if $result.skipped > 0;
  @parts.push: "{$result.passed} passed"   if $result.passed  > 0;
  @parts.join(', ');
}

method !style(--> Str) {
  q:to/CSS/;
body { font-family: -apple-system, sans-serif; margin: 1em; color: #222; }
h1 { margin-bottom: 0.2em; }
.summary { font-weight: bold; padding: 0.5em; background: #f0f0f0; border-radius: 4px; }
.summary.has-failures { background: #fee; }
.suite-file { margin-top: 1em; }
.group { margin-left: 1em; padding-left: 0.5em; border-left: 1px solid #eee; }
.group > .group-summary { font-weight: bold; cursor: pointer; padding: 0.2em 0; }
.group-body { margin-left: 1em; }
.example { padding: 0.15em 0.3em; margin: 0.15em 0; font-family: monospace; }
.example .marker { display: inline-block; width: 1.2em; text-align: center; font-weight: bold; }
.example.pass { color: #1b8a3a; }
.example.fail { color: #b30000; background: #fff5f5; }
.example.pending { color: #1370c4; background: #f5faff; }
.example.skipped { color: #777; }
.duration { color: #999; font-size: 0.85em; margin-left: 0.5em; }
.location { color: #aaa; font-size: 0.85em; margin-left: 0.5em; }
.failure-detail { background: #fff0f0; border-left: 3px solid #b30000; padding: 0.5em; margin: 0.3em 0 0.3em 1em; white-space: pre-wrap; }
.load-error { background: #fee; padding: 0.5em; margin: 0.5em 0; border-radius: 4px; }
CSS
}

method !emit($result, Bool :$aborted = False, Str :$order = 'defined', Int :$seed) {
  return if $!emitted;
  $!emitted = True;

  my $duration = $!started-at.defined ?? (now.Real - $!started-at) !! 0e0;
  my $summary = self!summary-line($result);
  my $summary-class = $result.failed > 0 ?? 'summary has-failures' !! 'summary';

  say '<!DOCTYPE html>';
  say '<html lang="en">';
  say '<head>';
  say '<meta charset="utf-8">';
  say '<title>Behave Test Report</title>';
  say '<style>';
  print self!style;
  say '</style>';
  say '</head>';
  say '<body>';
  say '<h1>Behave Test Report</h1>';
  say '<p class="' ~ $summary-class ~ '">' ~ self!escape($summary)
                                            ~ ' (' ~ sprintf('%.3fs', $duration) ~ ')'
                                            ~ '</p>';
  if $order eq 'random' && $seed.defined {
    say '<p class="meta">Randomized with seed ' ~ $seed ~ '</p>';
  }
  if $aborted {
    say '<p class="meta aborted">Run was aborted.</p>';
  }

  say '<div class="results">';
  for @!fragments -> $frag { say $frag }
  say '</div>';
  say '</body>';
  say '</html>';
}
