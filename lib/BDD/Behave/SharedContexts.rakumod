unit module BDD::Behave::SharedContexts;

class SharedContextRegistry {
  has %.contexts;

  method register(Str:D $name, Callable:D $block) {
    %!contexts{$name} = $block;
    $block;
  }

  method lookup(Str:D $name) {
    %!contexts{$name}:exists
      or die "Unknown shared context: '$name'";
    %!contexts{$name};
  }

  method exists(Str:D $name) {
    %!contexts{$name}:exists;
  }

  method names {
    %!contexts.keys.sort.List;
  }

  method clear {
    %!contexts = ();
  }
}

my SharedContextRegistry $REGISTRY .= new;

our sub registry() is export(:DEFAULT) {
  $REGISTRY;
}
