unit module BDD::Behave::SharedExamples;

class SharedExampleRegistry {
  has %.examples;

  method register(Str:D $name, Callable:D $block) {
    %!examples{$name} = $block;
    $block;
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
  }
}

my SharedExampleRegistry $REGISTRY .= new;

our sub registry() is export(:DEFAULT) {
  $REGISTRY;
}
