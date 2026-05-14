use BDD::Behave;
use BDD::Behave::Matcher;
use BDD::Behave::Matcher::Custom;
use BDD::Behave::Failures;

describe 'define-matcher returns a Matcher-doing factory', {
  it 'builds a DefinedMatcher that does Matcher', {
    my &be-multiple-of = define-matcher 'cm-spec-be-multiple-of',
      match => -> $actual, $expected { ?($actual %% $expected) };

    my $m = be-multiple-of(3);
    expect($m).to.be-a(Matcher);
    expect($m).to.be-a(DefinedMatcher);
  }

  it 'preserves the matcher name and args', {
    my &be-multiple-of = define-matcher 'cm-spec-name-args',
      match => -> $actual, $expected { ?($actual %% $expected) };

    my $m = be-multiple-of(3);
    expect($m.name).to.be('cm-spec-name-args');
    expect($m.args.List).to.eq((3,));
  }

  it 'evaluates the match block', {
    my &be-multiple-of = define-matcher 'cm-spec-matches',
      match => -> $actual, $expected { ?($actual %% $expected) };

    expect(be-multiple-of(3).matches(9)).to.be-truthy;
    expect(be-multiple-of(3).matches(10)).to.be-falsy;
  }
}

describe 'default behavior when blocks are omitted', {
  it 'has undefined failure-message and failure-message-negated', {
    my &is-zero = define-matcher 'cm-spec-is-zero',
      match => -> $actual { $actual == 0 };

    my $m = is-zero();
    expect($m.failure-message(1).defined).to.be-falsy;
    expect($m.failure-message-negated(1).defined).to.be-falsy;
  }

  it 'defaults description to the matcher name', {
    my &is-zero = define-matcher 'cm-spec-default-desc',
      match => -> $actual { $actual == 0 };

    expect(is-zero().description).to.be('cm-spec-default-desc');
  }
}

describe 'custom failure messages and description', {
  it 'invokes failure-message and failure-message-negated with actual + args', {
    my &be-multiple-of = define-matcher 'cm-spec-fm',
      match => -> $actual, $expected { ?($actual %% $expected) },
      failure-message => -> $actual, $expected {
        "expected $actual to be a multiple of $expected";
      },
      failure-message-negated => -> $actual, $expected {
        "expected $actual not to be a multiple of $expected";
      },
      description => -> $expected { "be a multiple of $expected" };

    my $m = be-multiple-of(3);
    expect($m.failure-message(10)).to.be('expected 10 to be a multiple of 3');
    expect($m.failure-message-negated(9)).to.be('expected 9 not to be a multiple of 3');
    expect($m.description).to.be('be a multiple of 3');
  }
}

describe 'default expected-value', {
  it 'returns the single arg for a one-arg matcher', {
    my &one = define-matcher 'cm-spec-ev-one',
      match => -> $actual, $expected { $actual == $expected };
    expect(one(7).expected-value).to.be(7);
  }

  it 'returns the list of args for a multi-arg matcher', {
    my &two = define-matcher 'cm-spec-ev-two',
      match => -> $actual, $a, $b { $actual >= $a && $actual <= $b };
    expect(two(1, 10).expected-value.List).to.eq((1, 10));
  }

  it 'returns the empty list for a no-arg matcher', {
    my &none = define-matcher 'cm-spec-ev-none',
      match => -> $actual { ?$actual };
    expect(none().expected-value.List).to.eq(().List);
  }

  it 'uses the expected-value block when provided', {
    my &be-multiple-of = define-matcher 'cm-spec-ev-block',
      match => -> $actual, $expected { ?($actual %% $expected) },
      expected-value => -> $expected { "any multiple of $expected" };

    expect(be-multiple-of(3).expected-value).to.be('any multiple of 3');
  }
}

describe 'option validation', {
  it 'requires a match block', {
    expect({
      define-matcher 'cm-spec-no-match',
        failure-message => -> $a { 'oops' };
    }).to.raise-error(/'match block is required'/);
  }

  it 'rejects unknown option keys', {
    expect({
      define-matcher 'cm-spec-bad-opt',
        match => -> $a { True },
        :totally-bogus(-> { 'x' });
    }).to.raise-error(/'unknown option'/);
  }

  it 'rejects non-Callable values', {
    expect({
      define-matcher 'cm-spec-bad-callable',
        match => -> $a { True },
        failure-message => 'not a Callable';
    }).to.raise-error(/'must be a Callable'/);
  }
}

describe 'CustomMatcherRegistry', {
  it 'is a singleton accessible via registry()', {
    my $reg = BDD::Behave::Matcher::Custom::registry();
    expect($reg).to.be-a(BDD::Behave::Matcher::Custom::CustomMatcherRegistry);
  }

  it 'tracks registered names', {
    my $reg = BDD::Behave::Matcher::Custom::registry();
    $reg.clear;

    define-matcher 'cm-spec-r1', match => -> $a { ?$a };
    define-matcher 'cm-spec-r2', match => -> $a { ?$a };

    expect($reg.names.List).to.eq(('cm-spec-r1', 'cm-spec-r2'));
    expect($reg.exists('cm-spec-r1')).to.be-truthy;
    expect($reg.exists('cm-spec-not-here')).to.be-falsy;

    $reg.clear;
  }

  it 'dies on lookup of an unknown name', {
    my $reg = BDD::Behave::Matcher::Custom::registry();
    expect({ $reg.lookup('cm-spec-missing') }).to.raise-error;
  }
}

describe 'matcher() helper looks up by name', {
  it 'returns a DefinedMatcher built from the registered config', {
    define-matcher 'cm-spec-be-even',
      match => -> $actual { ?($actual %% 2) },
      failure-message => -> $actual { "expected $actual to be even" };

    my $m = matcher('cm-spec-be-even');
    expect($m).to.be-a(DefinedMatcher);
    expect($m.matches(4)).to.be-truthy;
    expect($m.failure-message(5)).to.be('expected 5 to be even');
  }

  it 'dies for an unknown name', {
    expect({ matcher('cm-spec-totally-missing') }).to.raise-error;
  }
}

describe 'integration with expect(...).to.be(...)', {
  it 'passes when the matcher matches', {
    my &be-even = define-matcher 'cm-spec-int-even',
      match => -> $actual { ?($actual %% 2) },
      failure-message => -> $actual { "expected $actual to be even" };

    expect(4).to.be(be-even());
  }

  it 'records the custom failure message on a miss', {
    my &be-even = define-matcher 'cm-spec-int-even-fm',
      match => -> $actual { ?($actual %% 2) },
      failure-message => -> $actual { "expected $actual to be even" };

    Failures.list = ();
    expect(5).to.be(be-even());
    expect(Failures.list.elems).to.be(1);
    expect(Failures.list[0].message).to.be('expected 5 to be even');
    expect(Failures.list[0].given).to.be(5);
    Failures.list = ();
  }

  it 'routes negation through failure-message-negated', {
    my &be-even = define-matcher 'cm-spec-int-even-neg',
      match => -> $actual { ?($actual %% 2) },
      failure-message-negated => -> $actual { "expected $actual not to be even" };

    Failures.list = ();
    expect(4).to.not.be(be-even());
    expect(Failures.list.elems).to.be(1);
    expect(Failures.list[0].message).to.be('expected 4 not to be even');
    expect(Failures.list[0].negated).to.be-truthy;
    Failures.list = ();
  }
}

describe 'FALLBACK dispatch on ExpectationBuilder', {
  it 'lets registered matchers be called as methods on .to', {
    define-matcher 'cm-spec-be-positive',
      match => -> $actual { $actual > 0 },
      failure-message => -> $actual { "expected $actual to be positive" };

    expect(5).to.cm-spec-be-positive;
  }

  it 'passes args through to the match block', {
    define-matcher 'cm-spec-be-mult-of',
      match => -> $actual, $n { ?($actual %% $n) },
      failure-message => -> $actual, $n { "expected $actual to be a multiple of $n" };

    expect(9).to.cm-spec-be-mult-of(3);
    Failures.list = ();
    expect(10).to.cm-spec-be-mult-of(3);
    expect(Failures.list.elems).to.be(1);
    expect(Failures.list[0].message).to.be('expected 10 to be a multiple of 3');
    Failures.list = ();
  }

  it 'composes with .not', {
    define-matcher 'cm-spec-be-pos-neg',
      match => -> $actual { $actual > 0 },
      failure-message-negated => -> $actual { "expected $actual not to be positive" };

    expect(-1).to.not.cm-spec-be-pos-neg;

    Failures.list = ();
    expect(1).to.not.cm-spec-be-pos-neg;
    expect(Failures.list.elems).to.be(1);
    expect(Failures.list[0].message).to.be('expected 1 not to be positive');
    expect(Failures.list[0].negated).to.be-truthy;
    Failures.list = ();
  }

  it 'still dies for an unknown method', {
    expect({ expect(1).to.cm-spec-totally-bogus-not-a-matcher }).to.raise-error;
  }
}

describe 'named args reach the factory', {
  it 'binds named args through to the match block', {
    my &range-includes = define-matcher 'cm-spec-range-kw',
      match => -> $actual, :$min, :$max { $actual >= $min && $actual <= $max };

    my $m = range-includes(min => 1, max => 10);
    expect($m.matches(5)).to.be-truthy;
    expect($m.matches(11)).to.be-falsy;
    expect($m.kwargs<min>).to.be(1);
    expect($m.kwargs<max>).to.be(10);
  }
}

describe 'redefinition replaces an existing registration', {
  it 'lets the latest definition win', {
    my $reg = BDD::Behave::Matcher::Custom::registry();
    $reg.clear;

    define-matcher 'cm-spec-redef', match => -> $actual { $actual > 100 };
    define-matcher 'cm-spec-redef', match => -> $actual { $actual < 100 };

    expect(matcher('cm-spec-redef').matches(50)).to.be-truthy;
    expect(matcher('cm-spec-redef').matches(200)).to.be-falsy;

    $reg.clear;
  }
}
