
use v6.d;

# Re-export DSL functions for convenience
sub describe(|args) is export {
  state $impl = do {
    require ::('BDD::Behave::DSL');
    ::('BDD::Behave::DSL::&describe');
  };
  $impl(|args);
}

sub context(|args) is export {
  state $impl = do {
    require ::('BDD::Behave::DSL');
    ::('BDD::Behave::DSL::&context');
  };
  $impl(|args);
}

sub it(|args) is export {
  state $impl = do {
    require ::('BDD::Behave::DSL');
    ::('BDD::Behave::DSL::&it');
  };
  $impl(|args);
}

sub let(|args) is export {
  state $impl = do {
    require ::('BDD::Behave::DSL');
    ::('BDD::Behave::DSL::&let');
  };
  $impl(|args);
}

sub expect(|args) is export {
  state $impl = do {
    require ::('BDD::Behave::DSL');
    ::('BDD::Behave::DSL::&expect');
  };
  $impl(|args);
}
