use BDD::Behave::Benchmark::Format;
use BDD::Behave::Failures;
use BDD::Behave::Formatter;

unit class BDD::Behave::Formatter::JSON does BDD::Behave::Formatter;

has @!description-stack;
has @!examples;
has Int $!failure-watermark = 0;
has Str $!pending-auto-description;
has Bool $!multi-file = False;
has Int $!seed;
has Str $!order = 'defined';
has Bool $!emitted = False;
has Real $!start-time;
has @!load-errors;

method name(--> Str) { 'json' }

method !full-description(Str $description --> Str) {
  my @parts = @!description-stack.clone;
  @parts.push: $description;
  @parts.grep(*.defined).join(' ');
}

method !ex-record($example, Str $status, %extras = %()) {
  my $description = $!pending-auto-description // $example.description;
  my %record = (
    description      => $description,
    full_description => self!full-description($description),
    status           => $status,
    file             => $example.file.Str,
    line             => $example.line,
    duration         => $example.duration.defined ?? $example.duration.Real !! Real,
    tags             => $example.effective-tags.List,
  );
  for %extras.kv -> $k, $v { %record{$k} = $v }
  %record;
}

method suite-loading(Str :$file) { }

method suite-start($suite, Bool :$multi-file = False) {
  $!multi-file = $multi-file;
  $!start-time //= now.Real;
}

method suite-end($suite) { }

method group-start($group) {
  @!description-stack.push: $group.description;
}

method group-end($group) {
  @!description-stack.pop;
}

method group-around-skipped($group) { }

method example-start($example, Bool :$auto = False) {
  $!failure-watermark = Failures.list.elems;
  $!pending-auto-description = Str;
}

method example-auto-description($example, Str :$description) {
  $!pending-auto-description = $description;
}

method example-pass($example) {
  @!examples.push: self!ex-record($example, 'passed');
  $!pending-auto-description = Str;
}

method example-fail($example, :$failure-info) {
  my %fail = ();
  if $failure-info.defined {
    if $failure-info<exception>.defined {
      %fail<type>    = 'exception';
      %fail<message> = $failure-info<exception>.message;
    }
    if $failure-info<file>.defined { %fail<file> = $failure-info<file>.Str }
    if $failure-info<line>.defined { %fail<line> = $failure-info<line> }
  }
  my $count = Failures.list.elems;
  if $count > $!failure-watermark {
    my @new = Failures.list[$!failure-watermark .. $count - 1].grep(!*.from-runner-exception);
    if @new.elems {
      %fail<expectations> = @new.map(-> $fl {
        my %rec = (
          file     => $fl.file,
          line     => $fl.line,
          negated  => $fl.negated,
          given    => ($fl.given.defined    ?? $fl.given.gist    !! Str),
          expected => ($fl.expected.defined ?? $fl.expected.gist !! Str),
        );
        %rec<message>           = $fl.message           if $fl.message.defined;
        %rec<aggregation_label> = $fl.aggregation-label if $fl.aggregation-label.defined;
        %rec;
      }).List;
    }
  }
  @!examples.push: self!ex-record($example, 'failed', %( failure => %fail ));
  $!pending-auto-description = Str;
}

method example-pending($example) {
  my %extras = ();
  my $reason = $example.get-metadata('pending-reason');
  %extras<pending_reason> = $reason if $reason.defined;
  @!examples.push: self!ex-record($example, 'pending', %extras);
}

method example-skipped($example) {
  @!examples.push: self!ex-record($example, 'skipped');
}

method example-around-skipped($example) {
  @!examples.push: self!ex-record(
    $example, 'skipped',
    %( skip_reason => 'around-each did not invoke continuation' ),
  );
}

method example-slow($example, Real :$threshold) { }

method run-summary(
  $result,
  Bool :$aborted   = False,
  Int  :$fail-fast = 0,
  Str  :$order     = 'defined',
  Int  :$seed,
) {
  $!seed  = $seed  if $seed.defined;
  $!order = $order if $order.defined;
  return if $!multi-file;
  self!emit($result, :$aborted, :$fail-fast);
}

method profile-summary(@records, Int :$limit)        { }

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
) {
  $!seed  = $seed  if $seed.defined;
  $!order = $order;
  self!emit($result);
}

method multi-file-profile($runner, @records, Int :$limit)        { }
method multi-file-benchmark(
  $runner,
  @summaries, @regressions,
  Real     :$threshold,
  Str      :$format,
  IO::Path :$output,
) { }

method load-errors(@errors) {
  for @errors -> $err {
    @!load-errors.push: %(
      file    => $err<file>.Str,
      message => $err<message>.Str,
    );
  }
}

method !emit($result, Bool :$aborted = False, Int :$fail-fast = 0) {
  return if $!emitted;
  $!emitted = True;

  my %summary = (
    total    => $result.total,
    passed   => $result.passed,
    failed   => $result.failed,
    pending  => $result.pending,
    skipped  => $result.skipped,
    duration => ($!start-time.defined ?? (now.Real - $!start-time) !! Real),
  );

  my %doc = (
    version       => 1,
    summary       => %summary,
    summary_line  => self!summary-line($result),
    seed          => $!seed,
    order         => $!order,
    aborted       => $aborted,
    examples      => @!examples.List,
    load_errors   => @!load-errors.List,
  );

  say BDD::Behave::Benchmark::Format::to-json(%doc);
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
