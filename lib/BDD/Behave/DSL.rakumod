unit module BDD::Behave::DSL;

use BDD::Behave::Failure;
use BDD::Behave::Failures;
use BDD::Behave::Matcher;

need BDD::Behave::SpecRegistry;
need BDD::Behave::LetRuntime;
need BDD::Behave::SharedContexts;
need BDD::Behave::SharedExamples;
need BDD::Behave::Mock;

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
  BDD::Behave::Mock::double(|args);
}

our sub spy(|args) is export {
  BDD::Behave::Mock::spy(|args);
}

our sub allow(Mu \target) is export {
  BDD::Behave::Mock::allow(target);
}

our sub allow-any-instance-of(Mu \cls) is export {
  BDD::Behave::Mock::allow-any-instance-of(cls);
}

our sub anything()              is export { BDD::Behave::Mock::anything() }
our sub instance-of(Mu \type)   is export { BDD::Behave::Mock::instance-of(type) }
our sub hash-including(*%pairs) is export { BDD::Behave::Mock::hash-including(|%pairs) }
our sub array-including(*@items) is export { BDD::Behave::Mock::array-including(|@items) }

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

class BetweenExpectation {
  has Mu   $.given;
  has Bool $.negated = False;
  has Str  $.file;
  has Int  $.line;
  has      $.min;
  has      $.max;
  has Bool $!exclusive = False;
  has      $!recorded-failure;

  submethod BUILD(
    Mu :$given is raw, :$!negated, :$!file, :$!line, :$!min, :$!max,
  ) {
    $!given := $given;
  }

  method validate(--> Nil) {
    my $matcher = BeBetweenMatcher.new(
      :min($!min), :max($!max), :exclusive($!exclusive),
    );
    my $matched = ?$matcher.matches($!given);
    my $passed  = $!negated ?? !$matched !! $matched;

    if $passed {
      self.clear-failure;
      return;
    }

    my $message = $!negated
      ?? $matcher.failure-message-negated($!given)
      !! $matcher.failure-message($!given);

    self.replace-failure($message, $matcher);
  }

  method replace-failure(Str $msg, $matcher --> Nil) {
    self.clear-failure;
    my $f = Failure.new(
      :file($!file),
      :line($!line),
      :given($!given),
      :expected($matcher.expected-value),
      :negated($!negated),
      :message($msg),
    );
    Failures.list.push($f);
    $!recorded-failure = $f;
  }

  method clear-failure(--> Nil) {
    return unless $!recorded-failure.defined;
    my $list = Failures.list;
    my $idx  = $list.first({ $_ === $!recorded-failure }, :k);
    $list.splice($idx, 1) if $idx.defined;
    $!recorded-failure = Nil;
  }

  method inclusive {
    $!exclusive = False;
    self.validate;
    self;
  }

  method exclusive {
    $!exclusive = True;
    self.validate;
    self;
  }
}

class WithinExpectation {
  has Mu   $.given;
  has Bool $.negated = False;
  has Str  $.file;
  has Int  $.line;
  has      $.delta;

  submethod BUILD(
    Mu :$given is raw, :$!negated, :$!file, :$!line, :$!delta,
  ) {
    $!given := $given;
  }

  method of($expected --> Nil) {
    my $matcher = BeWithinMatcher.new(:delta($!delta), :$expected);
    my $matched = ?$matcher.matches($!given);
    my $passed  = $!negated ?? !$matched !! $matched;
    return if $passed;

    my $message = $!negated
      ?? $matcher.failure-message-negated($!given)
      !! $matcher.failure-message($!given);

    my $f = Failure.new(
      :file($!file),
      :line($!line),
      :given($!given),
      :expected($matcher.expected-value),
      :negated($!negated),
      :message($message),
    );
    Failures.list.push($f);
  }
}

class ExpectationBuilder {
  has $.given;
  has Bool $.negated is rw = False;
  has Int $.line;
  has Str $.file;

  method to { self }

  method not {
    my $new = ExpectationBuilder.new(
      :given($!given),
      :negated(True),
      :line($!line),
      :file($!file)
    );
    $new;
  }

  method !apply-matcher($matcher) {
    try {
      if $*BEHAVE-AUTO-MATCHERS.defined {
        $*BEHAVE-AUTO-MATCHERS.push(%(:$matcher, :negated($!negated)));
      }
    }

    my $matched = ?$matcher.matches($!given);
    my $passed  = $!negated ?? !$matched !! $matched;

    if !$passed {
      my $message = $!negated
        ?? $matcher.failure-message-negated($!given)
        !! $matcher.failure-message($!given);

      my $expected-for-failure = $matcher ~~ BeMatcher
        ?? $matcher.expected
        !! $matcher.expected-value;

      my $failure = Failure.new(
        :file($!file),
        :line($!line),
        :given($!given),
        :expected($expected-for-failure),
        :negated($!negated),
        :message($message),
      );
      Failures.list.push($failure);
    }

    $passed;
  }

  method be(|c) {
    my @pos = c.list;
    my %named = c.hash;

    my $resolved-expected;
    if %named.elems == 1 && @pos.elems == 0 {
      my $key = %named.keys[0];
      try {
        $resolved-expected = $*LET-RUNTIME.value($key) if $*LET-RUNTIME.defined;
        CATCH {
          default {
            die "Unknown let(:$key)";
          }
        }
      }
    } elsif @pos.elems == 1 {
      my $expected = @pos[0];

      $resolved-expected = $expected;
      if $expected ~~ Pair {
        try {
          $resolved-expected = $*LET-RUNTIME.value($expected.key) if $*LET-RUNTIME.defined;
        }
      }
    } else {
      die "be requires either a positional argument or a single named argument";
    }

    my $matcher = $resolved-expected ~~ Matcher
      ?? $resolved-expected
      !! BeMatcher.new(:expected($resolved-expected));

    self!apply-matcher($matcher);
  }

  method include(**@items, *%pairs) {
    my @expected = @items;
    @expected.append: %pairs.pairs;
    if @expected.elems == 0 {
      die "include requires at least one item";
    }
    self!apply-matcher(IncludeMatcher.new(:expected(@expected)));
  }

  method eq($expected) {
    self!apply-matcher(EqMatcher.new(:expected($expected)));
  }

  method contain-exactly(**@items) {
    self!apply-matcher(ContainExactlyMatcher.new(:expected(@items)));
  }

  method match-array($expected) {
    unless $expected ~~ Positional | Iterable {
      die "match-array requires an array argument";
    }
    self!apply-matcher(ContainExactlyMatcher.new(:expected($expected.list)));
  }

  method start-with(**@items) {
    if @items.elems == 0 {
      die "start-with requires at least one item";
    }
    self!apply-matcher(StartWithMatcher.new(:expected(@items)));
  }

  method end-with(**@items) {
    if @items.elems == 0 {
      die "end-with requires at least one item";
    }
    self!apply-matcher(EndWithMatcher.new(:expected(@items)));
  }

  method all(Mu \expected) {
    my $inner = expected ~~ Matcher
      ?? expected
      !! BeMatcher.new(:expected(expected));
    self!apply-matcher(AllMatcher.new(:inner($inner)));
  }

  method be-a(Mu \type) {
    self!apply-matcher(BeAMatcher.new(:type(type)));
  }

  method be-an(Mu \type) {
    self!apply-matcher(BeAMatcher.new(:type(type)));
  }

  method be-an-instance-of(Mu \type) {
    self!apply-matcher(BeAnInstanceOfMatcher.new(:type(type)));
  }

  method respond-to(**@names) {
    if @names.elems == 0 {
      die "respond-to requires at least one method name";
    }
    self!apply-matcher(RespondToMatcher.new(:expected(@names)));
  }

  method have-attributes(*%attrs) {
    if %attrs.elems == 0 {
      die "have-attributes requires at least one attribute name => value pair";
    }
    self!apply-matcher(HaveAttributesMatcher.new(:expected(%attrs)));
  }

  method be-greater-than($expected) {
    self!apply-matcher(BeGreaterThanMatcher.new(:$expected));
  }

  method be-gt($expected) {
    self!apply-matcher(BeGreaterThanMatcher.new(:$expected));
  }

  method be-greater-than-or-equal-to($expected) {
    self!apply-matcher(BeGreaterThanOrEqualMatcher.new(:$expected));
  }

  method be-gte($expected) {
    self!apply-matcher(BeGreaterThanOrEqualMatcher.new(:$expected));
  }

  method be-less-than($expected) {
    self!apply-matcher(BeLessThanMatcher.new(:$expected));
  }

  method be-lt($expected) {
    self!apply-matcher(BeLessThanMatcher.new(:$expected));
  }

  method be-less-than-or-equal-to($expected) {
    self!apply-matcher(BeLessThanOrEqualMatcher.new(:$expected));
  }

  method be-lte($expected) {
    self!apply-matcher(BeLessThanOrEqualMatcher.new(:$expected));
  }

  method be-between($min, $max) {
    my $expectation = BetweenExpectation.new(
      :given($!given),
      :negated($!negated),
      :file($!file),
      :line($!line),
      :$min,
      :$max,
    );
    $expectation.validate;
    $expectation;
  }

  method be-truthy() {
    self!apply-matcher(BeTruthyMatcher.new);
  }

  method be-falsy() {
    self!apply-matcher(BeFalsyMatcher.new);
  }

  method be-nil() {
    self!apply-matcher(BeNilMatcher.new);
  }

  method match(Regex $expected) {
    self!apply-matcher(MatchMatcher.new(:$expected));
  }

  method be-within($delta) {
    WithinExpectation.new(
      :given($!given),
      :negated($!negated),
      :file($!file),
      :line($!line),
      :$delta,
    );
  }

  method have-received(Str:D $method-name) {
    my $expectation = BDD::Behave::Mock::HaveReceivedExpectation.new(
      :target($!given),
      :$method-name,
      :negated($!negated),
      :file($!file),
      :line($!line),
    );
    $expectation.validate;
    $expectation;
  }
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
  my $caller-file = callframe(1).file.Str;
  my $caller-line = callframe(1).line.Int;

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
