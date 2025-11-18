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
  my $registry = registry();
  my $group = $registry.current-group-for($file)
    or die "let must be declared inside a describe/context block";
  my $definition = LetDefinition.new(:name($name.Str), :block($builder), :$file, :$line);
  $group.add-let($definition);
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

  method be($expected) {
    my $result = $!given ~~ $expected;
    $result = $!negated ?? !$result !! $result;

    if !$result {
      my $failure = Failure.new(
        :file($!file),
        :line($!line),
        :given($!given),
        :expected($expected),
        :negated($!negated)
      );
      Failures.list.push($failure);
    }

    $result;
  }
}

our sub expect($given) is export {
  my $caller-file = callframe(1).file.Str;
  my $caller-line = callframe(1).line.Int;

  ExpectationBuilder.new(
    :$given,
    :file($caller-file),
    :line($caller-line)
  );
}
