use BDD::Behave::Failures;
use BDD::Behave::Formatter;

unit class BDD::Behave::Formatter::JUnit does BDD::Behave::Formatter;

class TestCase {
  has Str  $.classname is rw = '';
  has Str  $.name      is rw = '';
  has Str  $.file      is rw;
  has Int  $.line      is rw;
  has Real $.time      is rw = 0e0;
  has Str  $.status    is rw = 'passed';
  has Str  $.failure-type    is rw;
  has Str  $.failure-message is rw;
  has Str  $.failure-body    is rw;
  has Str  $.skip-message    is rw;
}

class Testsuite {
  has Str       $.name is rw = '';
  has Str       $.file is rw;
  has TestCase  @.cases;
  has Real      $.time      is rw = 0e0;
  has Instant   $.started-at is rw;
}

has @!description-stack;
has Testsuite $!current-suite;
has Testsuite @!suites;
has Bool $!multi-file = False;
has Bool $!emitted    = False;
has Int  $!failure-watermark = 0;
has Str  $!pending-auto-description;
has Real $!total-time = 0e0;
has Int  $!tests   = 0;
has Int  $!failures = 0;
has Int  $!errors   = 0;
has Int  $!skipped  = 0;

method name(--> Str) { 'junit' }

method suite-loading(Str :$file) { }

method suite-start($suite, Bool :$multi-file = False) {
  $!multi-file = $multi-file;
  $!current-suite = Testsuite.new(
    :name($suite.description // $suite.file.basename),
    :file($suite.file.Str),
    :started-at(now.Instant),
  );
  @!suites.push: $!current-suite;
}

method suite-end($suite) { }

method group-start($group) {
  @!description-stack.push: $group.description;
}

method group-end($group) {
  @!description-stack.pop;
}

method group-around-skipped($group) { }

method !classname(--> Str) {
  @!description-stack.grep(*.defined).join(' > ');
}

method !ensure-suite($example) {
  unless $!current-suite.defined {
    $!current-suite = Testsuite.new(
      :name($example.file.basename),
      :file($example.file.Str),
      :started-at(now.Instant),
    );
    @!suites.push: $!current-suite;
  }
}

method !push-case($example, Str $status, %extras = %()) {
  self!ensure-suite($example);
  my $description = $!pending-auto-description // $example.description;
  my $tc = TestCase.new(
    :classname(self!classname),
    :name($description),
    :file($example.file.Str),
    :line($example.line),
    :time($example.duration.defined ?? $example.duration.Real !! 0e0),
    :$status,
  );
  for %extras.kv -> $k, $v {
    given $k {
      when 'failure-type'    { $tc.failure-type    = $v.Str }
      when 'failure-message' { $tc.failure-message = $v.Str }
      when 'failure-body'    { $tc.failure-body    = $v.Str }
      when 'skip-message'    { $tc.skip-message    = $v.Str }
    }
  }
  $!current-suite.cases.push: $tc;
  $!tests++;
  $!total-time += $tc.time;
  if $!current-suite.defined {
    $!current-suite.time += $tc.time;
  }
}

method example-start($example, Bool :$auto = False) {
  $!failure-watermark = Failures.list.elems;
  $!pending-auto-description = Str;
}

method example-auto-description($example, Str :$description) {
  $!pending-auto-description = $description;
}

method example-pass($example) {
  self!push-case($example, 'passed');
  $!pending-auto-description = Str;
}

method example-fail($example, :$failure-info) {
  my $is-error = $failure-info.defined && $failure-info<exception>.defined;
  my $msg-type = $is-error ?? 'Exception' !! 'Expectation';
  my $msg = $is-error
    ?? $failure-info<exception>.message
    !! self!summarize-expectations;
  my $body = $is-error
    ?? $failure-info<exception>.gist
    !! self!format-expectations;
  if $is-error {
    $!errors++;
    self!push-case($example, 'error',
      %( failure-type => $msg-type,
         failure-message => $msg,
         failure-body => $body ));
  } else {
    $!failures++;
    self!push-case($example, 'failed',
      %( failure-type => $msg-type,
         failure-message => $msg,
         failure-body => $body ));
  }
  $!pending-auto-description = Str;
}

method example-pending($example) {
  $!skipped++;
  my $reason = $example.get-metadata('pending-reason') // 'pending';
  self!push-case($example, 'pending',
    %( skip-message => "pending: $reason" ));
}

method example-skipped($example) {
  $!skipped++;
  self!push-case($example, 'skipped', %( skip-message => 'skipped' ));
}

method example-around-skipped($example) {
  $!skipped++;
  self!push-case($example, 'skipped',
    %( skip-message => 'around-each did not invoke continuation' ));
}

method example-slow($example, Real :$threshold) { }
method example-memory-leak($example, Int :$threshold) { }

method !summarize-expectations(--> Str) {
  my $count = Failures.list.elems;
  return 'unknown failure' unless $count > $!failure-watermark;
  my $f = Failures.list[$!failure-watermark];
  my $given    = $f.given.defined    ?? $f.given.gist    !! 'undefined';
  my $expected = $f.expected.defined ?? $f.expected.gist !! 'undefined';
  my $op       = $f.negated          ?? 'not to be'      !! 'to be';
  $f.message.defined
    ?? $f.message.lines[0]
    !! "Expected $given $op $expected";
}

method !format-expectations(--> Str) {
  my $count = Failures.list.elems;
  return '' unless $count > $!failure-watermark;
  my @parts;
  for Failures.list[$!failure-watermark .. $count - 1] -> $f {
    my @lines;
    @lines.push: "{$f.file}:{$f.line}";
    if $f.aggregation-label.defined {
      @lines.push: "  aggregate: {$f.aggregation-label}";
    }
    if $f.message.defined {
      @lines.push: "  $_" for $f.message.lines;
    } else {
      my $op = $f.negated ?? 'not to be' !! 'to be';
      @lines.push: "  Expected: {$f.given.gist}";
      @lines.push: "  $op:     {$f.expected.gist}";
    }
    @parts.push: @lines.join("\n");
  }
  @parts.join("\n\n");
}

method run-summary(
  $result,
  Bool :$aborted   = False,
  Int  :$fail-fast = 0,
  Str  :$order     = 'defined',
  Int  :$seed,
) {
  return if $!multi-file;
  self!emit;
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
  self!emit;
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

method load-errors(@errors) { }

method !xml-escape(Str $s --> Str) {
  return '' unless $s.defined;
  my $r = $s;
  $r = $r.subst('&',  '&amp;',  :g);
  $r = $r.subst('<',  '&lt;',   :g);
  $r = $r.subst('>',  '&gt;',   :g);
  $r = $r.subst('"',  '&quot;', :g);
  $r = $r.subst("'", '&apos;', :g);
  $r;
}

method !cdata(Str $s --> Str) {
  return '<![CDATA[]]>' unless $s.defined;
  '<![CDATA[' ~ $s.subst(']]>', ']]]]><![CDATA[>', :g) ~ ']]>';
}

method !render-case(TestCase $tc --> Str) {
  my $attrs = sprintf q[classname="%s" name="%s" file="%s" line="%d" time="%.6f"],
                     self!xml-escape($tc.classname),
                     self!xml-escape($tc.name),
                     self!xml-escape($tc.file),
                     ($tc.line // 0),
                     $tc.time;
  given $tc.status {
    when 'passed' {
      return "    <testcase $attrs/>";
    }
    when 'failed' {
      my $type    = self!xml-escape($tc.failure-type    // 'Expectation');
      my $message = self!xml-escape($tc.failure-message // '');
      my $body    = self!cdata($tc.failure-body // '');
      return join("\n",
        "    <testcase {$attrs}>",
        "      <failure type=\"{$type}\" message=\"{$message}\">{$body}</failure>",
        '    </testcase>',
      );
    }
    when 'error' {
      my $type    = self!xml-escape($tc.failure-type    // 'Exception');
      my $message = self!xml-escape($tc.failure-message // '');
      my $body    = self!cdata($tc.failure-body // '');
      return join("\n",
        "    <testcase {$attrs}>",
        "      <error type=\"{$type}\" message=\"{$message}\">{$body}</error>",
        '    </testcase>',
      );
    }
    when 'pending' | 'skipped' {
      my $message = self!xml-escape($tc.skip-message // '');
      return join("\n",
        "    <testcase {$attrs}>",
        "      <skipped message=\"{$message}\"/>",
        '    </testcase>',
      );
    }
  }
}

method !render-suite(Testsuite $ts --> Str) {
  my $failures = $ts.cases.grep(*.status eq 'failed').elems;
  my $errors   = $ts.cases.grep(*.status eq 'error').elems;
  my $skipped  = $ts.cases.grep(*.status eq any('pending', 'skipped')).elems;
  my $tests    = $ts.cases.elems;

  my $timestamp = $ts.started-at.defined
                    ?? DateTime.new($ts.started-at).Str
                    !! DateTime.now.Str;

  my $attrs = sprintf
    q[name="%s" tests="%d" failures="%d" errors="%d" skipped="%d" time="%.6f" timestamp="%s" file="%s"],
    self!xml-escape($ts.name),
    $tests, $failures, $errors, $skipped,
    $ts.time,
    $timestamp,
    self!xml-escape($ts.file // '');

  my @lines;
  @lines.push: "  <testsuite $attrs>";
  @lines.push: self!render-case($_) for $ts.cases;
  @lines.push: '  </testsuite>';
  @lines.join("\n");
}

method !emit {
  return if $!emitted;
  $!emitted = True;

  my $total-tests = @!suites.map({ .cases.elems }).sum;
  my $total-failures = @!suites.map({ .cases.grep(*.status eq 'failed').elems }).sum;
  my $total-errors   = @!suites.map({ .cases.grep(*.status eq 'error').elems }).sum;
  my $total-skipped  = @!suites.map({ .cases.grep(*.status eq any('pending','skipped')).elems }).sum;
  my $total-time     = @!suites.map({ .time }).sum;

  my $attrs = sprintf q[name="behave" tests="%d" failures="%d" errors="%d" skipped="%d" time="%.6f"],
                     $total-tests, $total-failures, $total-errors, $total-skipped, $total-time;

  say '<?xml version="1.0" encoding="UTF-8"?>';
  say "<testsuites $attrs>";
  for @!suites -> $ts { say self!render-suite($ts) }
  say '</testsuites>';
}
