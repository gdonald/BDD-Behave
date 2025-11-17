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

class LetRuntime is export {
  has LetDefinition @.definitions;
  has %.memo;

  method value(Str $name, *%context) {
    my $key = $name.subst(/^':'/, '');
    return %.memo{$key} if %.memo{$key}:exists;
    my $definition = @!definitions.reverse.first({ .name eq $key || .name eq ":$key" })
      or die "Unknown let($name)";
    %.memo{$key} = %context.elems ?? $definition.evaluate(|%context) !! $definition.evaluate;
  }

  method names {
    @!definitions.map(*.name).unique.List;
  }
}
