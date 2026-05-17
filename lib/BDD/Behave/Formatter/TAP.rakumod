use BDD::Behave::Failures;
use BDD::Behave::Formatter;

unit class BDD::Behave::Formatter::TAP does BDD::Behave::Formatter;

class Entry {
  has Str $.status   is required;   # 'ok' or 'not ok'
  has Str $.directive is rw;        # 'TODO' or 'SKIP' (optional)
  has Str $.directive-reason is rw;
  has Str $.description is rw = '';
  has @.diagnostics;                # yaml-ish key/value pairs (Array of Pair)
}

has @!description-stack;
has @!entries;
has Bool $!multi-file = False;
has Bool $!emitted    = False;
has Int  $!failure-watermark = 0;
has Str  $!pending-auto-description;

method name(--> Str) { 'tap' }

method suite-loading(Str :$file) { }

method suite-start($suite, Bool :$multi-file = False) {
  $!multi-file = $multi-file;
}

method suite-end($suite) { }

method group-start($group) {
  @!description-stack.push: $group.description;
}

method group-end($group) {
  @!description-stack.pop;
}

method group-around-skipped($group) { }

method !full-description(Str $description --> Str) {
  my @parts = @!description-stack.clone;
  @parts.push: $description;
  @parts.grep(*.defined).join(' ');
}

method example-start($example, Bool :$auto = False) {
  $!failure-watermark = Failures.list.elems;
  $!pending-auto-description = Str;
}

method example-auto-description($example, Str :$description) {
  $!pending-auto-description = $description;
}

method example-pass($example) {
  my $description = $!pending-auto-description // $example.description;
  @!entries.push: Entry.new(
    :status('ok'),
    :description(self!full-description($description)),
  );
  $!pending-auto-description = Str;
}

method example-fail($example, :$failure-info) {
  my $description = $!pending-auto-description // $example.description;
  my $entry = Entry.new(
    :status('not ok'),
    :description(self!full-description($description)),
  );
  my @diag;
  if $failure-info.defined && $failure-info<exception>.defined {
    @diag.push: 'severity' => 'error';
    @diag.push: 'message'  => $failure-info<exception>.message;
    @diag.push: 'file'     => $example.file.Str;
    @diag.push: 'line'     => $example.line;
  } else {
    @diag.push: 'severity' => 'fail';
    @diag.push: 'file'     => $example.file.Str;
    @diag.push: 'line'     => $example.line;
    my $count = Failures.list.elems;
    if $count > $!failure-watermark {
      my $first = Failures.list[$!failure-watermark];
      if $first.message.defined {
        @diag.push: 'message' => $first.message.lines[0];
      } else {
        my $op = $first.negated ?? 'not to be' !! 'to be';
        @diag.push: 'message' => "Expected " ~ $first.given.gist ~ " $op " ~ $first.expected.gist;
        @diag.push: 'got'      => $first.given.gist;
        @diag.push: 'expected' => $first.expected.gist;
      }
    }
  }
  $entry.diagnostics = @diag;
  @!entries.push: $entry;
  $!pending-auto-description = Str;
}

method example-pending($example) {
  my $reason = $example.get-metadata('pending-reason') // 'pending';
  my $description = $!pending-auto-description // $example.description;
  @!entries.push: Entry.new(
    :status('ok'),
    :description(self!full-description($description)),
    :directive('TODO'),
    :directive-reason($reason),
  );
}

method example-skipped($example) {
  my $description = $!pending-auto-description // $example.description;
  @!entries.push: Entry.new(
    :status('ok'),
    :description(self!full-description($description)),
    :directive('SKIP'),
    :directive-reason('skipped'),
  );
}

method example-around-skipped($example) {
  my $description = $!pending-auto-description // $example.description;
  @!entries.push: Entry.new(
    :status('ok'),
    :description(self!full-description($description)),
    :directive('SKIP'),
    :directive-reason('around-each did not invoke continuation'),
  );
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
  self!emit($aborted);
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

method !escape-description(Str $s --> Str) {
  return '' unless $s.defined;
  $s.subst('#', '\\#', :g);
}

method !yaml-string(Str $s --> Str) {
  return "''" unless $s.defined;
  my $body = $s.subst('\\', '\\\\', :g).subst("'", "''", :g);
  "'" ~ $body ~ "'";
}

method !render-diag(@diagnostics --> Str) {
  return '' unless @diagnostics.elems;
  my @lines;
  @lines.push: '  ---';
  for @diagnostics -> $pair {
    my $key = $pair.key;
    my $val = $pair.value;
    my $rendered = do given $val {
      when Int { $val.Str }
      when Real { $val.Str }
      default { self!yaml-string($val.Str) }
    };
    @lines.push: "  $key: $rendered";
  }
  @lines.push: '  ...';
  @lines.join("\n");
}

method !render-entry(Int $index, Entry $entry --> Str) {
  my $desc = self!escape-description($entry.description);
  my $line = "{$entry.status} $index";
  $line ~= " - $desc" if $desc.chars;
  if $entry.directive.defined {
    my $reason = $entry.directive-reason // '';
    $line ~= " # {$entry.directive} {$reason}";
  }
  if $entry.diagnostics.elems {
    $line ~= "\n" ~ self!render-diag($entry.diagnostics);
  }
  $line;
}

method !emit(Bool $aborted = False) {
  return if $!emitted;
  $!emitted = True;

  say 'TAP version 13';
  say "1..{@!entries.elems}";
  for @!entries.kv -> $i, $entry {
    say self!render-entry($i + 1, $entry);
  }
  say "Bail out! Aborted after fail-fast" if $aborted;
}
