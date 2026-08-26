unit module BDD::Behave::LetRuntime;

class LetDefinition is export {
  has Str $.name is required;
  has Callable $.block is required;
  has IO::Path $.file;
  has Int $.line;

  submethod BUILD(:$!name, :$!block, :$file, :$line) {
    $!file = $file ~~ IO::Path ?? $file !! $file.IO if $file.defined;
    $!line = $line if $line.defined;
  }

  method evaluate(*%context) {
    %context.elems ?? $!block(|%context) !! $!block();
  }
}

# `let(:name, ...)` and `let('name', ...)` name the same definition, so a name
# is indexed under its bare form whichever spelling declared it.
sub bare-name(Str $name --> Str) {
  $name.starts-with(':') ?? $name.substr(1) !! $name;
}

class LetRuntime is export {
  has LetDefinition @.definitions is rw;
  has %.memo;
  has %!by-name;

  submethod TWEAK { self!remember($_) for @!definitions }

  # A later definition of a name shadows an earlier one, which is what the
  # reversed scan this replaces gave.
  method !remember(LetDefinition $definition) {
    %!by-name{bare-name($definition.name)} = $definition;
  }

  method add-definition(LetDefinition $definition) {
    @!definitions.push($definition);
    self!remember($definition);
    $definition;
  }

  method value(Str $name, *%context) {
    my $key = bare-name($name);
    return %.memo{$key} if %.memo{$key}:exists;

    my $definition = %!by-name{$key} or die "Unknown let($name)";

    %.memo{$key} = %context.elems ?? $definition.evaluate(|%context) !! $definition.evaluate;
  }

  method names {
    @!definitions.map(*.name).unique.List;
  }

  method has-name(Str $name --> Bool) {
    %!by-name{bare-name($name)}:exists;
  }
}
