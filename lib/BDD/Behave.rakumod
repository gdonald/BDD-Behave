
use v6.d;

# Re-export DSL functions with lazy loading
# Each function uses 'state' to cache the implementation after first require
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

sub let-bang(|args) is export {
  state $impl = do {
    require ::('BDD::Behave::DSL');
    ::('BDD::Behave::DSL::&let-bang');
  };
  $impl(|args);
}

sub subject(|args) is export {
  state $impl = do {
    require ::('BDD::Behave::DSL');
    ::('BDD::Behave::DSL::&subject');
  };
  $impl(|args);
}

sub subject-bang(|args) is export {
  state $impl = do {
    require ::('BDD::Behave::DSL');
    ::('BDD::Behave::DSL::&subject-bang');
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

sub aggregate-failures(|args) is export {
  state $impl = do {
    require ::('BDD::Behave::DSL');
    ::('BDD::Behave::DSL::&aggregate-failures');
  };
  $impl(|args);
}

sub is-expected() is export {
  state $impl = do {
    require ::('BDD::Behave::DSL');
    ::('BDD::Behave::DSL::&is-expected');
  };
  $impl();
}

sub before-all(|args) is export {
  state $impl = do {
    require ::('BDD::Behave::DSL');
    ::('BDD::Behave::DSL::&before-all');
  };
  $impl(|args);
}

sub after-all(|args) is export {
  state $impl = do {
    require ::('BDD::Behave::DSL');
    ::('BDD::Behave::DSL::&after-all');
  };
  $impl(|args);
}

sub before-each(|args) is export {
  state $impl = do {
    require ::('BDD::Behave::DSL');
    ::('BDD::Behave::DSL::&before-each');
  };
  $impl(|args);
}

sub after-each(|args) is export {
  state $impl = do {
    require ::('BDD::Behave::DSL');
    ::('BDD::Behave::DSL::&after-each');
  };
  $impl(|args);
}

sub around-each(|args) is export {
  state $impl = do {
    require ::('BDD::Behave::DSL');
    ::('BDD::Behave::DSL::&around-each');
  };
  $impl(|args);
}

sub around-all(|args) is export {
  state $impl = do {
    require ::('BDD::Behave::DSL');
    ::('BDD::Behave::DSL::&around-all');
  };
  $impl(|args);
}

sub shared-context(|args) is export {
  state $impl = do {
    require ::('BDD::Behave::DSL');
    ::('BDD::Behave::DSL::&shared-context');
  };
  $impl(|args);
}

sub include-context(|args) is export {
  state $impl = do {
    require ::('BDD::Behave::DSL');
    ::('BDD::Behave::DSL::&include-context');
  };
  $impl(|args);
}

sub shared-examples(|args) is export {
  state $impl = do {
    require ::('BDD::Behave::DSL');
    ::('BDD::Behave::DSL::&shared-examples');
  };
  $impl(|args);
}

sub include-examples(|args) is export {
  state $impl = do {
    require ::('BDD::Behave::DSL');
    ::('BDD::Behave::DSL::&include-examples');
  };
  $impl(|args);
}

sub it-behaves-like(|args) is export {
  state $impl = do {
    require ::('BDD::Behave::DSL');
    ::('BDD::Behave::DSL::&it-behaves-like');
  };
  $impl(|args);
}

sub fit(|args) is export {
  state $impl = do {
    require ::('BDD::Behave::DSL');
    ::('BDD::Behave::DSL::&fit');
  };
  $impl(|args);
}

sub xit(|args) is export {
  state $impl = do {
    require ::('BDD::Behave::DSL');
    ::('BDD::Behave::DSL::&xit');
  };
  $impl(|args);
}

sub fdescribe(|args) is export {
  state $impl = do {
    require ::('BDD::Behave::DSL');
    ::('BDD::Behave::DSL::&fdescribe');
  };
  $impl(|args);
}

sub xdescribe(|args) is export {
  state $impl = do {
    require ::('BDD::Behave::DSL');
    ::('BDD::Behave::DSL::&xdescribe');
  };
  $impl(|args);
}

sub fcontext(|args) is export {
  state $impl = do {
    require ::('BDD::Behave::DSL');
    ::('BDD::Behave::DSL::&fcontext');
  };
  $impl(|args);
}

sub double(|args) is export {
  state $impl = do {
    require ::('BDD::Behave::DSL');
    ::('BDD::Behave::DSL::&double');
  };
  $impl(|args);
}

sub spy(|args) is export {
  state $impl = do {
    require ::('BDD::Behave::DSL');
    ::('BDD::Behave::DSL::&spy');
  };
  $impl(|args);
}

sub allow(Mu \target) is export {
  state $impl = do {
    require ::('BDD::Behave::DSL');
    ::('BDD::Behave::DSL::&allow');
  };
  $impl(target);
}

sub allow-any-instance-of(Mu \cls) is export {
  state $impl = do {
    require ::('BDD::Behave::DSL');
    ::('BDD::Behave::DSL::&allow-any-instance-of');
  };
  $impl(cls);
}

sub anything() is export {
  state $impl = do {
    require ::('BDD::Behave::DSL');
    ::('BDD::Behave::DSL::&anything');
  };
  $impl();
}

sub instance-of(Mu \type) is export {
  state $impl = do {
    require ::('BDD::Behave::DSL');
    ::('BDD::Behave::DSL::&instance-of');
  };
  $impl(type);
}

sub hash-including(*%pairs) is export {
  state $impl = do {
    require ::('BDD::Behave::DSL');
    ::('BDD::Behave::DSL::&hash-including');
  };
  $impl(|%pairs);
}

sub array-including(*@items) is export {
  state $impl = do {
    require ::('BDD::Behave::DSL');
    ::('BDD::Behave::DSL::&array-including');
  };
  $impl(|@items);
}

sub xcontext(|args) is export {
  state $impl = do {
    require ::('BDD::Behave::DSL');
    ::('BDD::Behave::DSL::&xcontext');
  };
  $impl(|args);
}

sub define-matcher(Str:D $name, *%blocks) is export {
  state $impl = do {
    require ::('BDD::Behave::DSL');
    ::('BDD::Behave::DSL::&define-matcher');
  };
  $impl($name, |%blocks);
}

sub matcher(Str:D $name, |c) is export {
  state $impl = do {
    require ::('BDD::Behave::DSL');
    ::('BDD::Behave::DSL::&matcher');
  };
  $impl($name, |c);
}
