unit module BDD::Behave::DSL;

use BDD::Behave::Failure;
use BDD::Behave::Failures;

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

constant RESERVED-META = set <tag tags skipped focused>;

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

our sub it(Str $description, &block, *%meta) is export {
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

our sub fit(Str $description, &block, *%meta) is export {
  it($description, &block, |%meta, :focused);
}

our sub xit(Str $description, &block, *%meta) is export {
  it($description, &block, |%meta, :skipped);
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

    my $result = $!given ~~ $resolved-expected;
    $result = $!negated ?? !$result !! $result;

    if !$result {
      my $failure = Failure.new(
        :file($!file),
        :line($!line),
        :given($!given),
        :expected($resolved-expected),
        :negated($!negated)
      );
      Failures.list.push($failure);
    }

    $result;
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
