use BDD::Behave;
use BDD::Behave::Matcher;
use BDD::Behave::Matcher::Boolean;
use BDD::Behave::Matcher::Core;
use BDD::Behave::Matcher::Numeric;

# A matcher with no description of its own falls back to its type name, which is
# what a matcher written outside behave gets for free.
my class PlainMatcher does Matcher {
  method matches($actual --> Bool) { $actual eq 'ok' }
}

describe 'a matcher that describes nothing of its own', {
  it 'falls back to its type name', {
    expect(PlainMatcher.new.description.contains('PlainMatcher')).to.be-truthy;
  }

  it 'still reports no failure message', {
    expect(PlainMatcher.new.failure-message('x').defined).to.be-falsy;
  }

  it 'still reports no negated failure message', {
    expect(PlainMatcher.new.failure-message-negated('x').defined).to.be-falsy;
  }

  it 'still reports no expected value', {
    expect(PlainMatcher.new.expected-value).to.be(Nil);
  }
}

describe 'a matcher composed with and', {
  let(:composed, {
    BeGreaterThanMatcher.new(:expected(1)).and(BeLessThanMatcher.new(:expected(9)));
  });

  context 'given a value both parts accept', {
    before-each { composed().matches(5) }

    it 'matches', {
      expect(composed().matches(5)).to.be-truthy;
    }

    it 'names no failing part', {
      expect(composed().failing-matcher).to.be(Nil);
    }
  }

  context 'given a value the second part rejects', {
    before-each { composed().matches(20) }

    it 'does not match', {
      expect(composed().matches(20)).to.be-falsy;
    }

    it 'names the part that failed', {
      expect(composed().failing-matcher.description).to.eq('be less than 9');
    }

    it 'reports what that part said', {
      expect(composed().failure-message(20)).to.include('be less than 9 failed');
    }
  }

  context 'given a failing part with no message of its own', {
    let(:silent, { EqMatcher.new(:expected('ok')).and(PlainMatcher.new) });

    before-each { silent().matches('nope') }

    it 'reports that the part did not match', {
      expect(silent().failure-message('nope')).to.include('did not match');
    }
  }
}

describe 'a matcher composed with or', {
  let(:composed, {
    EqMatcher.new(:expected('first')).or(EqMatcher.new(:expected('second')));
  });

  context 'given a value the second part accepts', {
    before-each { composed().matches('second') }

    it 'matches', {
      expect(composed().matches('second')).to.be-truthy;
    }

    it 'names the part that matched', {
      expect(composed().matched-matcher.description).to.eq('eq "second"');
    }

    it 'reports the matching part when the match was not wanted', {
      expect(composed().failure-message-negated('second'))
        .to.include('but eq "second" matched');
    }
  }

  context 'given a value no part accepts', {
    before-each { composed().matches('neither') }

    it 'does not match', {
      expect(composed().matches('neither')).to.be-falsy;
    }

    it 'names no matching part', {
      expect(composed().matched-matcher).to.be(Nil);
    }

    it 'reports that none matched', {
      expect(composed().failure-message('neither')).to.include('but none matched');
    }
  }
}

describe 'composing a matcher with something that is not one', {
  it 'refuses to build an and', {
    expect({ EqMatcher.new(:expected(1)).and('not a matcher') })
      .to.raise-error(/'requires Matcher'/);
  }

  it 'refuses to extend an and', {
    my $composed = EqMatcher.new(:expected(1)).and(EqMatcher.new(:expected(2)));

    expect({ $composed.and('not a matcher') }).to.raise-error(/'requires Matcher'/);
  }
}
