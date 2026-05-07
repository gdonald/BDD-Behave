unit module BDD::Behave::DSL;

use BDD::Behave::Failure;
use BDD::Behave::Failures;

need BDD::Behave::SpecRegistry;
need BDD::Behave::LetRuntime;
need BDD::Behave::SharedContexts;
need BDD::Behave::SharedExamples;

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

our proto sub describe(|) is export {*}

our multi sub describe(Str $description, &block, *%meta) is export {
  my $file = &block.file.IO;
  my $line = &block.line;
  my @tags = normalize-tags(%meta);
  registry().register-group(
    :$description,
    :&block,
    :$file,
    :$line,
    :@tags,
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

sub register-hook(Str $phase, &block) {
  my $entry = registry().current-entry;

  unless $entry && $entry.stack.elems {
    die "$phase must be called inside a describe/context block";
  }

  my $current = $entry.stack[*-1];
  $current.add-hook($phase, &block);
  
  &block;
}

our sub before-all(&block) is export { register-hook('before-all', &block) }
our sub after-all(&block)  is export { register-hook('after-all',  &block) }
our sub before-each(&block) is export { register-hook('before-each', &block) }
our sub after-each(&block)  is export { register-hook('after-each',  &block) }

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
  registry().register-example(
    :$description,
    :&block,
    :$file,
    :$line,
    :@tags,
    :skipped(%meta<skipped> // False),
    :focused(%meta<focused> // False),
  );
  Nil;
}

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
