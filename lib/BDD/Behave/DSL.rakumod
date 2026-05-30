unit module BDD::Behave::DSL;

use BDD::Behave::Expectation;
use BDD::Behave::Failure;
use BDD::Behave::Failures;

need BDD::Behave::SpecRegistry;
need BDD::Behave::LetRuntime;
need BDD::Behave::SharedContexts;
need BDD::Behave::SharedExamples;
need BDD::Behave::Mock::ArgMatcher;
need BDD::Behave::Mock::Double;
need BDD::Behave::Mock::Allow;
need BDD::Behave::Mock::Spy;
need BDD::Behave::Matcher::Custom;
need BDD::Behave::Benchmark;
need BDD::Behave::Time;

sub registry() { BDD::Behave::SpecRegistry::registry() }
sub shared-context-registry() { BDD::Behave::SharedContexts::registry() }
sub shared-examples-registry() { BDD::Behave::SharedExamples::registry() }
constant LetDefinition = BDD::Behave::LetRuntime::LetDefinition;

sub normalize-tags(%meta --> List) {
  my @tags;
  for <tag tags> -> $key {
    next unless %meta{$key}:exists;
    my $value = %meta{$key};
    next unless $value.defined;
    if $value ~~ Positional {
      @tags.append: $value.list.map(*.Str);
    } else {
      @tags.push: $value.Str;
    }
  }
  @tags.unique.List;
}

constant RESERVED-META = set <tag tags skipped focused auto-description>;

sub extract-extra-meta(%meta --> Hash) {
  my %extra;
  for %meta.kv -> $key, $value {
    next if $key (elem) RESERVED-META;
    %extra{$key} = $value;
  }
  %extra;
}

sub parse-hook-filter(%filter --> Hash) {
  my @include-tags;
  my @exclude-tags;
  my %meta;
  for %filter.kv -> $key, $value {
    given $key {
      when 'tag'|'tags' {
        if $value ~~ Positional {
          @include-tags.append: $value.list.map(*.Str);
        } else {
          @include-tags.push: $value.Str;
        }
      }
      when 'exclude-tag'|'exclude-tags' {
        if $value ~~ Positional {
          @exclude-tags.append: $value.list.map(*.Str);
        } else {
          @exclude-tags.push: $value.Str;
        }
      }
      default {
        %meta{$key} = $value;
      }
    }
  }
  %(
    :include-tags(@include-tags.unique.list),
    :exclude-tags(@exclude-tags.unique.list),
    :%meta,
  );
}

our proto sub describe(|) is export {*}

our multi sub describe(Str $description, &block, *%meta) is export {
  my $file = &block.file.IO;
  my $line = &block.line;
  my @tags = normalize-tags(%meta);
  my %extra-meta = extract-extra-meta(%meta);
  registry().register-group(
    :$description,
    :&block,
    :$file,
    :$line,
    :@tags,
    :%extra-meta,
    :skipped(%meta<skipped> // False),
    :focused(%meta<focused> // False),
  );
  Nil;
}

our multi sub describe(*@, *%) is export {
  die "describe expects a description string and a block";
}

our sub context(|c) is export { describe(|c) }

our sub fdescribe(Str $description, &block, *%meta) is export {
  describe($description, &block, |%meta, :focused);
}

our sub xdescribe(Str $description, &block, *%meta) is export {
  describe($description, &block, |%meta, :skipped);
}

our sub fcontext(|c) is export { fdescribe(|c) }
our sub xcontext(|c) is export { xdescribe(|c) }

our sub let(|c) is export {
  my @pos = c.list;
  my %named = c.hash;
  my $name;
  my $block;

  my $has-block = @pos.first(* ~~ Callable).defined;

  unless $has-block {
    my $fetch-name;

    if @pos.elems == 1 && @pos[0] ~~ Str && !%named {
      $fetch-name = @pos[0];
    } elsif @pos.elems == 0 && %named.elems == 1 {
      $fetch-name = %named.keys[0].Str;
    } else {
      die "let expects either let('name', \{ block \}) or let(:name, \{ block \}), or a fetch form let('name') / let(:name)";
    }

    return let-value($fetch-name);
  }

  if @pos.elems == 2 && @pos[0] ~~ Str && @pos[1] ~~ Callable {
    $name = @pos[0];
    $block = @pos[1];
  } elsif @pos.elems == 1 && @pos[0] ~~ Callable && %named.elems == 1 {
    $block = @pos[0];
    $name = %named.keys[0].Str;
  } else {
    die "let expects either let('name', \{ block \}) or let(:name, \{ block \})";
  }

  my $file = $block.file.IO;
  my $line = $block.line;
  my $definition = LetDefinition.new(:name($name), :block($block), :$file, :$line);

  my $in-runtime = False;
  try {
    $in-runtime = $*LET-RUNTIME.defined;
  }

  if $in-runtime {
    $*LET-RUNTIME.add-definition($definition);

    return Proxy.new(
      FETCH => method () {
        $*LET-RUNTIME.value($name);
      },
      STORE => method ($new) {
        die "Let values are read-only";
      }
    );
  }

  my $registry = registry();
  my $entry = $registry.current-entry;

  if $entry && $entry.stack.elems {
    my $current = $entry.stack[*-1];
    $current.add-let($definition);
  } else {
    my $suite = $registry.suite-for($file);
    $suite.add-let($definition);
  }

  $definition;
}

our sub let-value(Str:D $name) is export {
  my $runtime;
  try {
    $runtime = $*LET-RUNTIME if $*LET-RUNTIME.defined;
  }

  unless $runtime.defined {
    die "let(:$name) fetch form must be called while an example is running";
  }

  $runtime.value($name);
}

our sub let-bang(|c) is export {
  my $entry = registry().current-entry;

  unless $entry && $entry.stack.elems {
    die "let-bang must be called inside a describe/context block";
  }

  my $definition = let(|c);
  unless $definition ~~ LetDefinition {
    die "let-bang must be called inside a describe/context block";
  }

  my $name = $definition.name.subst(/^':'/, '');
  my $current = $entry.stack[*-1];
  my &force-block = sub { $*LET-RUNTIME.value($name) if $*LET-RUNTIME.defined };
  $current.add-hook('before-each', &force-block);

  $definition;
}

sub register-subject(Str:D $name, &block, Bool :$is-named) {
  my $primary = let($name, &block);
  if $is-named {
    let('subject', sub { $*LET-RUNTIME.value($name) });
  }
  $primary;
}

sub install-subject-eager-hook(Str $caller-name) {
  my $entry = registry().current-entry;
  unless $entry && $entry.stack.elems {
    die "$caller-name must be called inside a describe/context block";
  }
  my $current = $entry.stack[*-1];
  my &force-block = sub { $*LET-RUNTIME.value('subject') if $*LET-RUNTIME.defined };
  $current.add-hook('before-each', &force-block);
}

our proto sub subject(|) is export {*}

our multi sub subject(--> Mu) {
  my $rt;
  try { $rt = $*LET-RUNTIME if $*LET-RUNTIME.defined }
  unless $rt.defined {
    die "subject() with no arguments must be called inside an example";
  }
  $rt.value('subject');
}

our multi sub subject(Str:D $name, &block) {
  register-subject($name, &block, :is-named);
}

our multi sub subject(&block, *%named) {
  if %named.elems == 0 {
    register-subject('subject', &block);
  } elsif %named.elems == 1 {
    register-subject(%named.keys[0].Str, &block, :is-named);
  } else {
    die "subject expects at most one named argument";
  }
}

our proto sub subject-bang(|) is export {*}

our multi sub subject-bang(Str:D $name, &block) {
  install-subject-eager-hook('subject-bang');
  register-subject($name, &block, :is-named);
}

our multi sub subject-bang(&block, *%named) {
  install-subject-eager-hook('subject-bang');
  if %named.elems == 0 {
    register-subject('subject', &block);
  } elsif %named.elems == 1 {
    register-subject(%named.keys[0].Str, &block, :is-named);
  } else {
    die "subject-bang expects at most one named argument";
  }
}

sub register-hook(Str $phase, &block, *%filter) {
  my $entry = registry().current-entry;

  unless $entry && $entry.stack.elems {
    die "$phase must be called inside a describe/context block";
  }

  my $current = $entry.stack[*-1];
  my %parsed = parse-hook-filter(%filter);
  $current.add-hook($phase, &block, |%parsed);
}

our sub before-all(&block, *%filter) is export {
  register-hook('before-all', &block, |%filter);
}
our sub after-all(&block, *%filter) is export {
  register-hook('after-all', &block, |%filter);
}
our sub before-each(&block, *%filter) is export {
  register-hook('before-each', &block, |%filter);
}
our sub after-each(&block, *%filter) is export {
  register-hook('after-each', &block, |%filter);
}
our sub around-each(&block, *%filter) is export {
  register-hook('around-each', &block, |%filter);
}
our sub around-all(&block, *%filter) is export {
  register-hook('around-all', &block, |%filter);
}

our sub shared-context(Str:D $name, &block) is export {
  shared-context-registry().register($name, &block);
}

our sub include-context(Str:D $name, |args) is export {
  my $entry = registry().current-entry;

  unless $entry && $entry.stack.elems {
    die "include-context must be called inside a describe/context block";
  }

  my &block = shared-context-registry().lookup($name);
  block(|args);
}

our sub shared-examples(Str:D $name, &block) is export {
  shared-examples-registry().register($name, &block);
}

our sub include-examples(Str:D $name, |args) is export {
  my $entry = registry().current-entry;

  unless $entry && $entry.stack.elems {
    die "include-examples must be called inside a describe/context block";
  }

  my &block = shared-examples-registry().lookup($name);
  block(|args);
}

our sub it-behaves-like(Str:D $name, |args) is export {
  my $entry = registry().current-entry;

  unless $entry && $entry.stack.elems {
    die "it-behaves-like must be called inside a describe/context block";
  }

  my $parent-group = $entry.stack[*-1];
  my &shared-block = shared-examples-registry().lookup($name);
  my &wrapper = sub { shared-block(|args) };

  registry().register-group(
    description => "behaves like '$name'",
    block       => &wrapper,
    file        => $parent-group.file,
    line        => &shared-block.line,
  );
}

our proto sub it(|) is export {*}

our multi sub it(Str $description, &block, *%meta) is export {
  my $file = &block.file.IO;
  my $line = &block.line;
  my @tags = normalize-tags(%meta);
  my %extra-meta = extract-extra-meta(%meta);
  registry().register-example(
    :$description,
    :&block,
    :$file,
    :$line,
    :@tags,
    :%extra-meta,
    :skipped(%meta<skipped> // False),
    :focused(%meta<focused> // False),
  );
  Nil;
}

our multi sub it(&block, *%meta) is export {
  my $file = &block.file.IO;
  my $line = &block.line;
  my $description = "example at {$file.basename}:$line";
  my @tags = normalize-tags(%meta);
  my %extra-meta = extract-extra-meta(%meta);
  my $example = registry().register-example(
    :$description,
    :&block,
    :$file,
    :$line,
    :@tags,
    :%extra-meta,
    :skipped(%meta<skipped> // False),
    :focused(%meta<focused> // False),
  );
  $example.set-metadata(:auto-description(True));
  Nil;
}

our sub double(|args) is export {
  BDD::Behave::Mock::Double::double(|args);
}

our sub spy(|args) is export {
  BDD::Behave::Mock::Spy::spy(|args);
}

our sub allow(Mu \target) is export {
  BDD::Behave::Mock::Allow::allow(target);
}

our sub allow-any-instance-of(Mu \cls) is export {
  BDD::Behave::Mock::Allow::allow-any-instance-of(cls);
}

our sub anything()              is export { BDD::Behave::Mock::ArgMatcher::anything() }
our sub instance-of(Mu \type)   is export { BDD::Behave::Mock::ArgMatcher::instance-of(type) }
our sub hash-including(*%pairs) is export { BDD::Behave::Mock::ArgMatcher::hash-including(|%pairs) }
our sub array-including(*@items) is export { BDD::Behave::Mock::ArgMatcher::array-including(|@items) }

our sub define-matcher(Str:D $name, *%blocks) is export {
  BDD::Behave::Matcher::Custom::define-matcher($name, |%blocks);
}

our sub matcher(Str:D $name, |c) is export {
  BDD::Behave::Matcher::Custom::matcher($name, |c);
}

our sub benchmark(|c) is export {
  BDD::Behave::Benchmark::benchmark(|c);
}

our sub freeze-time(|c) is export {
  BDD::Behave::Time::freeze-time(|c);
}

our sub travel-to($when, &block) is export {
  BDD::Behave::Time::travel-to($when, &block);
}

our sub travel-by(Real() $delta) is export {
  BDD::Behave::Time::travel-by($delta);
}

our sub current-time() is export {
  BDD::Behave::Time::current-time();
}

our proto sub fit(|) is export {*}

our multi sub fit(Str $description, &block, *%meta) is export {
  it($description, &block, |%meta, :focused);
}

our multi sub fit(&block, *%meta) is export {
  it(&block, |%meta, :focused);
}

our proto sub xit(|) is export {*}

our multi sub xit(Str $description, &block, *%meta) is export {
  it($description, &block, |%meta, :skipped);
}

our multi sub xit(&block, *%meta) is export {
  it(&block, |%meta, :skipped);
}

our proto sub specify(|) is export {*}

our multi sub specify(Str $description, &block, *%meta) is export {
  it($description, &block, |%meta);
}

our multi sub specify(&block, *%meta) is export {
  it(&block, |%meta);
}

our proto sub example(|) is export {*}

our multi sub example(Str $description, &block, *%meta) is export {
  it($description, &block, |%meta);
}

our multi sub example(&block, *%meta) is export {
  it(&block, |%meta);
}

our proto sub pending(|) is export {*}

our multi sub pending(Str $reason, &block, *%meta) is export {
  my $file = &block.file.IO;
  my $line = &block.line;
  my @tags = normalize-tags(%meta);
  my %extra-meta = extract-extra-meta(%meta);
  my $example = registry().register-example(
    :description($reason),
    :&block,
    :$file,
    :$line,
    :@tags,
    :%extra-meta,
  );
  $example.mark-pending(:reason($reason));
  Nil;
}

sub caller-outside-behave() {
  my $depth = 1;
  loop {
    my $frame = callframe($depth);
    last unless $frame.defined;
    my $f = $frame.file // '';
    last unless $f.contains('BDD/Behave');
    $depth++;
  }
  callframe($depth);
}

our multi sub pending(Str $reason, *%meta) is export {
  my $frame = caller-outside-behave();
  my $file = ($frame.defined ?? $frame.file !! 'unknown').IO;
  my $line = ($frame.defined ?? $frame.line.Int !! 0);
  my &block = sub { Nil };
  my @tags = normalize-tags(%meta);
  my %extra-meta = extract-extra-meta(%meta);
  my $example = registry().register-example(
    :description($reason),
    :&block,
    :$file,
    :$line,
    :@tags,
    :%extra-meta,
  );
  $example.mark-pending(:reason($reason));
  Nil;
}


sub format-inner-failure($f --> Str) {
  my $location = "{$f.file // ''}:{$f.line // 0}";
  if $f.message.defined {
    my @lines = $f.message.lines;
    my $head  = "  - $location: " ~ (@lines.head // '');
    my @tail  = @lines.skip(1).map({ "      $_" });
    ($head, |@tail).join("\n");
  } elsif $f.given.defined || $f.expected.defined {
    my $op = $f.negated ?? 'not to be' !! 'to be';
    "  - $location:\n      Expected: {$f.given.raku}\n      $op: {$f.expected.raku}";
  } else {
    "  - $location";
  }
}

sub run-aggregate-failures(Str $label, &block, Str $file, Int $line --> Nil) {
  my $watermark = Failures.list.elems;
  my $exception;
  {
    my $*BEHAVE-AGGREGATION-LABEL = $label;
    my $*BEHAVE-AGGREGATING = True;
    try {
      block();
      CATCH {
        when X::BDD::Behave::ExpectationFailed { }
        default { $exception = $_; }
      }
    }
  }

  my @inner = Failures.list[$watermark .. *].list;

  if $exception.defined {
    @inner.push: Failure.new(
      :$file, :$line,
      :message('exception in aggregate-failures: ' ~ $exception.message),
      :aggregation-label($label),
    );
  }

  return unless @inner.elems;

  Failures.list.splice($watermark, *);

  my $n = @inner.elems;
  my $header = "$n expectation" ~ ($n == 1 ?? '' !! 's')
             ~ ' failed inside aggregate-failures';
  my @body = @inner.map(&format-inner-failure);
  my $message = ($header, |@body).join("\n");

  Failures.list.push(Failure.new(
    :$file, :$line, :$message,
    :aggregation-label($label),
  ));
}

our sub capture-failures(&block --> List) is export {
  my $watermark = Failures.list.elems;
  {
    my $*BEHAVE-AGGREGATING = True;
    try {
      block();
      CATCH {
        when X::BDD::Behave::ExpectationFailed { }
      }
    }
  }
  my @captured = Failures.list[$watermark .. *].list;
  Failures.list.splice($watermark, *);
  @captured.List;
}

sub user-callsite(--> List) {
  my $depth = 1;
  loop {
    my $frame = callframe($depth);
    last unless $frame.defined;
    my $file = ($frame.file // '').Str;
    if !$file.contains('lib/BDD/Behave') {
      return ($file, $frame.line.Int).List;
    }
    $depth++;
    last if $depth > 30;
  }
  ('', 0).List;
}

our proto sub aggregate-failures(|) is export {*}

our multi sub aggregate-failures(&block) is export {
  my ($caller-file, $caller-line) := user-callsite();
  my $inherited;
  try { $inherited = $*BEHAVE-AGGREGATION-LABEL if $*BEHAVE-AGGREGATION-LABEL.defined; }
  run-aggregate-failures($inherited // Str, &block, $caller-file, $caller-line);
}

our multi sub aggregate-failures(Str:D $label, &block) is export {
  my ($caller-file, $caller-line) := user-callsite();
  run-aggregate-failures($label, &block, $caller-file, $caller-line);
}

our sub is-expected() is export {
  my $caller-file = callframe(1).file.Str;
  my $caller-line = callframe(1).line.Int;

  my $rt;
  try { $rt = $*LET-RUNTIME if $*LET-RUNTIME.defined }
  unless $rt.defined {
    die "is-expected must be called inside an example";
  }

  my $resolved-given;
  try {
    $resolved-given = $rt.value('subject');
    CATCH {
      default {
        die "is-expected requires a subject (define one with `subject`)";
      }
    }
  }

  ExpectationBuilder.new(
    :given($resolved-given),
    :file($caller-file),
    :line($caller-line)
  );
}

our sub expect(|c) is export {
  # Walk up callframes to the first one outside the BDD::Behave codebase so
  # the failure location points at the user's expect(...) call site, not at
  # the internal proxy in lib/BDD/Behave.rakumod that re-dispatches to here.
  my $frame = caller-outside-behave();
  my $caller-file = ($frame.defined ?? $frame.file.Str !! 'unknown');
  my $caller-line = ($frame.defined ?? $frame.line.Int !! 0);

  my @pos = c.list;
  my %named = c.hash;

  my $resolved-given;
  if %named.elems == 1 && @pos.elems == 0 {
    my $key = %named.keys[0];
    
    try {
      
      $resolved-given = $*LET-RUNTIME.value($key) if $*LET-RUNTIME.defined;
      
      CATCH {
        default {
          
          die "Unknown let(:$key): " ~ .message;
        }
      }
    }
  } elsif @pos.elems == 1 {
    my $given = @pos[0];
  
    $resolved-given = $given;
    if $given ~~ Pair {
      try {
        $resolved-given = $*LET-RUNTIME.value($given.key) if $*LET-RUNTIME.defined;
      }
    }
  } else {
    die "expect requires either a positional argument or a single named argument";
  }

  ExpectationBuilder.new(
    :given($resolved-given),
    :file($caller-file),
    :line($caller-line)
  );
}
