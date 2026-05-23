use BDD::Behave::Formatter;
use BDD::Behave::Failures;

unit class BDD::Behave::Formatter::JsonEvents does BDD::Behave::Formatter;

has Int $!failure-watermark = 0;

method name(--> Str) { 'json-events' }

sub emit(%event --> Nil) {
  $*OUT.put(to-json-line(%event));
}

sub to-json-line(%h --> Str) {
  json-value(%h);
}

sub json-value($v --> Str) {
  given $v {
    when Nil      { 'null' }
    when Bool     { $v ?? 'true' !! 'false' }
    when Int      { $v.Str }
    when Real     { my $s = $v.Str; $s eq 'NaN' || $s eq 'Inf' || $s eq '-Inf' ?? 'null' !! $s }
    when Str      { json-string($v) }
    when Positional { '[' ~ $v.list.map(&json-value).join(',') ~ ']' }
    when Associative {
      my @pairs = $v.kv.rotor(2).map(-> ($k, $val) { json-string($k.Str) ~ ':' ~ json-value($val) });
      '{' ~ @pairs.sort.join(',') ~ '}';
    }
    default { json-string($v.gist) }
  }
}

sub json-string(Str $s --> Str) {
  my $out = $s;
  $out = $out.subst('\\', '\\\\', :g);
  $out = $out.subst('"',  '\\"',  :g);
  $out = $out.subst("\n", '\\n',  :g);
  $out = $out.subst("\r", '\\r',  :g);
  $out = $out.subst("\t", '\\t',  :g);
  $out = $out.subst(/<:Cc>/, { sprintf('\\u%04x', $/.Str.ord) }, :g);
  '"' ~ $out ~ '"';
}

method node-id($node --> Str) {
  $node.file.absolute ~ ':' ~ $node.line;
}

method suite-loading(Str :$file) {
  emit %( :type<suite-loading>, :$file );
}

method suite-start($suite, Bool :$multi-file = False) {
  emit %(
    :type<suite-start>,
    :id(self.node-id($suite)),
    :description($suite.description),
    :file($suite.file.absolute),
    :line($suite.line),
    :$multi-file,
  );
}

method suite-end($suite) {
  emit %(
    :type<suite-end>,
    :id(self.node-id($suite)),
  );
}

method group-start($group) {
  emit %(
    :type<group-start>,
    :id(self.node-id($group)),
    :description($group.description),
    :file($group.file.absolute),
    :line($group.line),
  );
}

method group-end($group) {
  emit %(
    :type<group-end>,
    :id(self.node-id($group)),
  );
}

method group-around-skipped($group) {
  emit %(
    :type<group-around-skipped>,
    :id(self.node-id($group)),
  );
}

method example-start($example, Bool :$auto = False) {
  emit %(
    :type<example-start>,
    :id(self.node-id($example)),
    :description($example.description),
    :file($example.file.absolute),
    :line($example.line),
    :$auto,
  );
}

method example-auto-description($example, Str :$description) {
  emit %(
    :type<example-auto-description>,
    :id(self.node-id($example)),
    :$description,
  );
}

method example-pass($example) {
  emit %(
    :type<example-pass>,
    :id(self.node-id($example)),
    :description($example.description),
    :file($example.file.absolute),
    :line($example.line),
    :duration($example.duration.defined ?? $example.duration.Real !! 0.0),
  );
}

method example-fail($example, :$failure-info) {
  my %payload = (
    :type<example-fail>,
    :id(self.node-id($example)),
    :description($example.description),
    :file($example.file.absolute),
    :line($example.line),
    :duration($example.duration.defined ?? $example.duration.Real !! 0.0),
  );
  with $failure-info {
    %payload<failure-description> = ($failure-info<description> // '').Str;
    %payload<failure-file>        = ($failure-info<file> // '').Str;
    %payload<failure-line>        = ($failure-info<line> // 0).Int;
    with $failure-info<exception> {
      %payload<exception-message>   = .message;
      %payload<exception-backtrace> = .backtrace.full.Str;
    }
  }
  my $total = Failures.list.elems;
  my @new   = $total > $!failure-watermark
    ?? Failures.list[$!failure-watermark ..^ $total].grep(!*.from-runner-exception).List
    !! ().List;
  $!failure-watermark = $total;
  %payload<failures> = @new.map({ %(
    :file($_.file // ''),
    :line($_.line // 0),
    :given(($_.given // '').gist),
    :expected(($_.expected // '').gist),
    :message(($_.?message // Str).defined ?? $_.message !! ''),
    :aggregation-label(($_.?aggregation-label // Str).defined ?? $_.aggregation-label !! ''),
    :negated(?$_.negated),
  ) }).List;
  emit %payload;
}

method example-pending($example) {
  emit %(
    :type<example-pending>,
    :id(self.node-id($example)),
    :description($example.description),
    :file($example.file.absolute),
    :line($example.line),
  );
}

method example-skipped($example) {
  emit %(
    :type<example-skipped>,
    :id(self.node-id($example)),
    :description($example.description),
    :file($example.file.absolute),
    :line($example.line),
  );
}

method example-around-skipped($example) {
  emit %(
    :type<example-around-skipped>,
    :id(self.node-id($example)),
    :description($example.description),
    :file($example.file.absolute),
    :line($example.line),
  );
}

method example-retry($example, Int :$attempt, Int :$max-attempts) {
  emit %(
    :type<example-retry>,
    :id(self.node-id($example)),
    :description($example.description),
    :file($example.file.absolute),
    :line($example.line),
    :attempt($attempt.Int),
    :max-attempts($max-attempts.Int),
  );
}

method example-slow($example, Real :$threshold) {
  emit %(
    :type<example-slow>,
    :id(self.node-id($example)),
    :threshold($threshold.Real),
    :duration($example.duration.defined ?? $example.duration.Real !! 0.0),
  );
}

method example-memory-leak($example, Int :$threshold) {
  emit %(
    :type<example-memory-leak>,
    :id(self.node-id($example)),
    :threshold($threshold.Int),
    :delta($example.memory-delta.defined ?? $example.memory-delta.Int !! 0),
  );
}

method retry-summary(@records) {
  for @records -> $rec {
    emit %(
      :type<retry-record>,
      :description($rec.description.Str),
      :location($rec.location.Str),
      :attempts($rec.attempts.Int),
      :max-attempts($rec.max-attempts.Int),
      :outcome($rec.outcome.Str),
    );
  }
}

method profile-summary(@records, Int :$limit) {
  return unless $limit > 0;
  for @records -> $rec {
    my $ex = $rec<example>;
    emit %(
      :type<profile-record>,
      :id($ex.defined ?? self.node-id($ex) !! ''),
      :description(($rec<description> // '').Str),
      :duration(($rec<duration> // 0).Real),
      :file($ex.defined ?? $ex.file.absolute !! ''),
      :line($ex.defined ?? $ex.line.Int !! 0),
    );
  }
}

method memory-profile-summary(@records, Int :$limit) {
  return unless $limit > 0;
  for @records -> $rec {
    my $ex = $rec<example>;
    emit %(
      :type<memory-record>,
      :id($ex.defined ?? self.node-id($ex) !! ''),
      :description(($rec<description> // '').Str),
      :delta(($rec<delta> // 0).Int),
      :before(($rec<before> // 0).Int),
      :after(($rec<after>  // 0).Int),
      :file($ex.defined ?? $ex.file.absolute !! ''),
      :line($ex.defined ?? $ex.line.Int !! 0),
    );
  }
}

method benchmark-summary-section(
  @summaries, @regressions,
  Real     :$threshold,
  Str      :$format,
  IO::Path :$output,
  :$runner,
) {
  for @summaries -> %s {
    my $ex = %s<example>;
    emit %(
      :type<benchmark-record>,
      :id($ex.defined ?? self.node-id($ex) !! ''),
      :description((%s<description> // '').Str),
      :key((%s<key> // '').Str),
      :label(%s<label>.defined ?? %s<label>.Str !! ''),
      :position((%s<position> // 0).Int),
      :runs((%s<runs> // 0).Int),
      :iterations((%s<iterations> // 0).Int),
      :timings(%s<timings>.list.map(*.Real).List),
      :min((%s<min> // 0).Real),
      :max((%s<max> // 0).Real),
      :mean((%s<mean> // 0).Real),
      :median((%s<median> // 0).Real),
      :total((%s<total> // 0).Real),
      :file($ex.defined ?? $ex.file.absolute !! ''),
      :line($ex.defined ?? $ex.line.Int !! 0),
    );
  }
}

method run-summary(
  $result,
  Bool :$aborted   = False,
  Int  :$fail-fast = 0,
  Str  :$order     = 'defined',
  Int  :$seed,
) {
  emit %(
    :type<run-summary>,
    :total($result.total.Int),
    :passed($result.passed.Int),
    :failed($result.failed.Int),
    :pending($result.pending.Int),
    :skipped($result.skipped.Int),
    :aborted(?$aborted),
    :fail-fast($fail-fast.Int),
    :$order,
    :seed($seed.defined ?? $seed.Int !! 0),
  );
}

method load-errors(@errors) {
  for @errors -> $err {
    emit %(
      :type<load-error>,
      :file(($err<file> // '').Str),
      :message(($err<message> // '').Str),
    );
  }
}
