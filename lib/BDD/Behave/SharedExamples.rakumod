unit module BDD::Behave::SharedExamples;

class SharedExampleRegistry {
  has %.examples;
  has %!lines;

  method register(Str:D $name, Callable:D $block, Int :$line = $block.line) {
    %!examples{$name} = $block;
    %!lines{$name} = $line;
    $block;
  }

  method line-of(Str:D $name --> Int) {
    self.lookup($name);
    %!lines{$name};
  }

  method lookup(Str:D $name) {
    %!examples{$name}:exists
      or die "Unknown shared examples: '$name'";
    %!examples{$name};
  }

  method exists(Str:D $name) {
    %!examples{$name}:exists;
  }

  method names {
    %!examples.keys.sort.List;
  }

  method clear {
    %!examples = ();
    %!lines = ();
  }
}

my SharedExampleRegistry $REGISTRY .= new;

our sub registry() is export(:DEFAULT) {
  $REGISTRY;
}
