use BDD::Behave;
use BDD::Behave::Matcher;
use BDD::Behave::Matcher::Core;
use BDD::Behave::Matcher::Numeric;
use BDD::Behave::Matcher::Collection;
use BDD::Behave::Matcher::String;
use BDD::Behave::Failures;

describe 'Matcher.and composition', {
  it 'returns an AndMatcher when called on any Matcher', {
    my $m = BeMatcher.new(:expected(5)).and(BeMatcher.new(:expected(Int)));
    expect($m).to.be-a(AndMatcher);
    expect($m).to.be-a(Matcher);
  }

  it 'passes when all inner matchers pass', {
    my $combo = BeGreaterThanMatcher.new(:expected(0))
      .and(BeLessThanMatcher.new(:expected(100)));
    expect($combo.matches(50)).to.be-truthy;
  }

  it 'fails when any inner matcher fails', {
    my $combo = BeGreaterThanMatcher.new(:expected(0))
      .and(BeLessThanMatcher.new(:expected(100)));
    expect($combo.matches(200)).to.be-falsy;
    expect($combo.matches(-5)).to.be-falsy;
  }

  it 'short-circuits at the first failing matcher', {
    my $combo = BeGreaterThanMatcher.new(:expected(0))
      .and(BeLessThanMatcher.new(:expected(100)));
    $combo.matches(-5);
    expect($combo.failing-index).to.be(0);

    $combo.matches(200);
    expect($combo.failing-index).to.be(1);
  }

  it 'flattens chained .and calls into a single AndMatcher', {
    my $a = BeMatcher.new(:expected(Int));
    my $b = BeGreaterThanMatcher.new(:expected(0));
    my $c = BeLessThanMatcher.new(:expected(100));
    my $combo = $a.and($b).and($c);
    expect($combo).to.be-a(AndMatcher);
    expect($combo.matchers.elems).to.be(3);
  }

  it 'supports multiple matchers in a single .and call', {
    my $combo = BeMatcher.new(:expected(Int)).and(
      BeGreaterThanMatcher.new(:expected(0)),
      BeLessThanMatcher.new(:expected(100)),
    );
    expect($combo.matchers.elems).to.be(3);
    expect($combo.matches(50)).to.be-truthy;
  }
}

describe 'Matcher.or composition', {
  it 'returns an OrMatcher when called on any Matcher', {
    my $m = BeMatcher.new(:expected(5)).or(BeMatcher.new(:expected(10)));
    expect($m).to.be-a(OrMatcher);
    expect($m).to.be-a(Matcher);
  }

  it 'passes when any inner matcher passes', {
    my $combo = BeMatcher.new(:expected(5))
      .or(BeMatcher.new(:expected(10)));
    expect($combo.matches(5)).to.be-truthy;
    expect($combo.matches(10)).to.be-truthy;
  }

  it 'fails when no inner matcher passes', {
    my $combo = BeMatcher.new(:expected(5))
      .or(BeMatcher.new(:expected(10)));
    expect($combo.matches(7)).to.be-falsy;
  }

  it 'short-circuits at the first matching matcher', {
    my $combo = BeMatcher.new(:expected(5))
      .or(BeMatcher.new(:expected(10)));
    $combo.matches(10);
    expect($combo.matched-index).to.be(1);

    $combo.matches(5);
    expect($combo.matched-index).to.be(0);
  }

  it 'flattens chained .or calls into a single OrMatcher', {
    my $combo = BeMatcher.new(:expected(1))
      .or(BeMatcher.new(:expected(2)))
      .or(BeMatcher.new(:expected(3)));
    expect($combo).to.be-a(OrMatcher);
    expect($combo.matchers.elems).to.be(3);
  }

  it 'supports multiple matchers in a single .or call', {
    my $combo = BeMatcher.new(:expected(1)).or(
      BeMatcher.new(:expected(2)),
      BeMatcher.new(:expected(3)),
    );
    expect($combo.matchers.elems).to.be(3);
    expect($combo.matches(2)).to.be-truthy;
  }
}

describe 'mixing .and and .or with nesting', {
  it 'groups left-to-right', {
    my $combo = BeMatcher.new(:expected(1))
      .and(BeMatcher.new(:expected(Int)))
      .or(BeMatcher.new(:expected(99)));

    expect($combo).to.be-a(OrMatcher);
    expect($combo.matches(1)).to.be-truthy;
    expect($combo.matches(99)).to.be-truthy;
    expect($combo.matches(7)).to.be-falsy;
  }

  it 'allows explicit nesting via inner composites', {
    my $inner = BeMatcher.new(:expected(1)).or(BeMatcher.new(:expected(2)));
    my $combo = BeMatcher.new(:expected(Int)).and($inner);
    expect($combo).to.be-a(AndMatcher);
    expect($combo.matches(1)).to.be-truthy;
    expect($combo.matches(2)).to.be-truthy;
    expect($combo.matches(3)).to.be-falsy;
  }
}

describe 'composition with custom matchers', {
  it 'composes define-matcher factories with .and', {
    my &positive = define-matcher 'comp-spec-positive',
      match => -> $a { $a > 0 };
    my &small = define-matcher 'comp-spec-small',
      match => -> $a { $a < 100 };

    my $combo = positive().and(small());
    expect($combo.matches(50)).to.be-truthy;
    expect($combo.matches(200)).to.be-falsy;
    expect($combo.matches(-1)).to.be-falsy;
  }

  it 'composes define-matcher factories with .or', {
    my &is-zero  = define-matcher 'comp-spec-zero',  match => -> $a { $a == 0 };
    my &is-one   = define-matcher 'comp-spec-one',   match => -> $a { $a == 1 };

    my $combo = is-zero().or(is-one());
    expect($combo.matches(0)).to.be-truthy;
    expect($combo.matches(1)).to.be-truthy;
    expect($combo.matches(2)).to.be-falsy;
  }
}

describe 'integration with expect(...).to.be(...)', {
  it 'passes when AND composite matches', {
    Failures.list = ();
    expect(50).to.be(
      BeGreaterThanMatcher.new(:expected(0))
        .and(BeLessThanMatcher.new(:expected(100)))
    );
    expect(Failures.list.elems).to.be(0);
    Failures.list = ();
  }

  it 'records one failure when AND composite fails', {
    Failures.list = ();
    expect(200).to.be(
      BeGreaterThanMatcher.new(:expected(0))
        .and(BeLessThanMatcher.new(:expected(100)))
    );
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }

  it 'passes when OR composite matches any side', {
    Failures.list = ();
    expect(5).to.be(
      BeMatcher.new(:expected(5)).or(BeMatcher.new(:expected(10)))
    );
    expect(Failures.list.elems).to.be(0);
    Failures.list = ();
  }

  it 'records one failure when OR composite fails all sides', {
    Failures.list = ();
    expect(7).to.be(
      BeMatcher.new(:expected(5)).or(BeMatcher.new(:expected(10)))
    );
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }
}

describe 'failure messages from composites', {
  it 'AND failure message names the failing inner matcher', {
    Failures.list = ();
    expect(200).to.be(
      BeGreaterThanMatcher.new(:expected(0))
        .and(BeLessThanMatcher.new(:expected(100)))
    );
    expect(Failures.list[0].message).to.include('be greater than 0');
    expect(Failures.list[0].message).to.include('be less than 100');
    Failures.list = ();
  }

  it 'OR failure message names both inner matchers', {
    Failures.list = ();
    expect(7).to.be(
      BeMatcher.new(:expected(5)).or(BeMatcher.new(:expected(10)))
    );
    expect(Failures.list[0].message).to.include('be 5');
    expect(Failures.list[0].message).to.include('be 10');
    expect(Failures.list[0].message).to.include('none matched');
    Failures.list = ();
  }
}

describe 'negation', {
  it 'AND composite under .not passes when the AND fails', {
    Failures.list = ();
    expect(200).to.not.be(
      BeGreaterThanMatcher.new(:expected(0))
        .and(BeLessThanMatcher.new(:expected(100)))
    );
    expect(Failures.list.elems).to.be(0);
    Failures.list = ();
  }

  it 'AND composite under .not records the negated message when the AND passes', {
    Failures.list = ();
    expect(50).to.not.be(
      BeGreaterThanMatcher.new(:expected(0))
        .and(BeLessThanMatcher.new(:expected(100)))
    );
    expect(Failures.list.elems).to.be(1);
    expect(Failures.list[0].negated).to.be-truthy;
    expect(Failures.list[0].message).to.include('not to');
    Failures.list = ();
  }

  it 'OR composite under .not passes when no inner matcher matches', {
    Failures.list = ();
    expect(7).to.not.be(
      BeMatcher.new(:expected(5)).or(BeMatcher.new(:expected(10)))
    );
    expect(Failures.list.elems).to.be(0);
    Failures.list = ();
  }

  it 'OR composite under .not records which matcher matched on a miss', {
    Failures.list = ();
    expect(5).to.not.be(
      BeMatcher.new(:expected(5)).or(BeMatcher.new(:expected(10)))
    );
    expect(Failures.list.elems).to.be(1);
    expect(Failures.list[0].negated).to.be-truthy;
    expect(Failures.list[0].message).to.include('matched');
    Failures.list = ();
  }
}

describe 'description', {
  it 'AND description joins inner descriptions with " and "', {
    my $combo = BeGreaterThanMatcher.new(:expected(0))
      .and(BeLessThanMatcher.new(:expected(100)));
    expect($combo.description).to.be('be greater than 0 and be less than 100');
  }

  it 'OR description joins inner descriptions with " or "', {
    my $combo = BeMatcher.new(:expected(5)).or(BeMatcher.new(:expected(10)));
    expect($combo.description).to.be('be 5 or be 10');
  }

  it 'nested composites render naturally', {
    my $inner = BeMatcher.new(:expected(1)).or(BeMatcher.new(:expected(2)));
    my $combo = BeMatcher.new(:expected(Int)).and($inner);
    expect($combo.description).to.include('and');
    expect($combo.description).to.include('or');
  }
}

describe 'argument validation', {
  it 'rejects non-Matcher arguments to .and', {
    expect({
      BeMatcher.new(:expected(1)).and(42)
    }).to.raise-error(/'requires Matcher'/);
  }

  it 'rejects non-Matcher arguments to .or', {
    expect({
      BeMatcher.new(:expected(1)).or('not a matcher')
    }).to.raise-error(/'requires Matcher'/);
  }
}

describe 'composition with built-in matchers', {
  it 'composes IncludeMatcher with another matcher via .and', {
    my $combo = IncludeMatcher.new(:expected([1]))
      .and(StartWithMatcher.new(:expected([1])));
    expect($combo.matches([1, 2, 3])).to.be-truthy;
    expect($combo.matches([2, 3, 1])).to.be-falsy;
  }

  it 'composes string matchers with .or', {
    my $combo = StartWithMatcher.new(:expected(['hello']))
      .or(EndWithMatcher.new(:expected(['world'])));
    expect($combo.matches('hello there')).to.be-truthy;
    expect($combo.matches('say world')).to.be-truthy;
    expect($combo.matches('foobar')).to.be-falsy;
  }
}
