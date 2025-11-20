unit module BDD::Behave::DSL;

use BDD::Behave::Failure;
use BDD::Behave::Failures;

need BDD::Behave::SpecRegistry;
need BDD::Behave::LetRuntime;

sub registry() { BDD::Behave::SpecRegistry::registry() }
constant LetDefinition = BDD::Behave::LetRuntime::LetDefinition;

our proto sub describe(|) is export {*}

our multi sub describe(Str $description, &block) is export {
  my $file = &block.file.IO;
  my $line = &block.line;
  registry().register-group(
    :$description,
    :&block,
    :$file,
    :$line
  );
  Nil;
}

our multi sub describe(*@) is export {
  die "describe expects a description string and a block";
}

our sub context(|c) is export { describe(|c) }

our sub let(|c) is export {
  my $builder = c.list[0] // die "let expects a block";
  die "let expects a block" unless $builder ~~ Callable;

  my %named = c.hash;
  my $name = %named.keys.[0] // die "let expects a named argument";

  my $file = $builder.file.IO;
  my $line = $builder.line;
  my $definition = LetDefinition.new(:name($name.Str), :block($builder), :$file, :$line);

  # Check runtime mode
  try {
    if $*LET-RUNTIME.defined {
      # Inside an executing test, so add to the runtime
      $*LET-RUNTIME.add-definition($definition);
      return $definition;
    }
  }

  # In registration mode, add to the appropriate container
  my $registry = registry();
  my $entry = $registry.current-entry;
  if $entry && $entry.stack.elems {
    # Could be inside a group or an example
    my $current = $entry.stack[*-1];
    $current.add-let($definition);
  } else {
    # Top level, add to the suite
    my $suite = $registry.suite-for($file);
    $suite.add-let($definition);
  }

  $definition;
}

our sub it(Str $description, &block) is export {
  my $file = &block.file.IO;
  my $line = &block.line;
  registry().register-example(
    :$description,
    :&block,
    :$file,
    :$line
  );
  Nil;
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

    # If called with a named parameter, resolve from let runtime
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
      # If expected is a Pair, resolve it from the let runtime
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

  # If called with a named parameter, resolve from let runtime
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
    # If given is a Pair, resolve it from the let runtime
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
