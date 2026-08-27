use BDD::Behave;
use BDD::Behave::Matcher::Change;

# The expectation builder drives this matcher through its captured state, so
# the matcher's own `matches` is exercised here directly.
sub matcher-for(&observable, *%bounds --> ChangeMatcher) {
  my $matcher = ChangeMatcher.new(:&observable);

  for %bounds.kv -> $name, $value {
    given $name {
      when 'from'         { $matcher.expected-from = $value;         $matcher.has-from = True }
      when 'to'           { $matcher.expected-to = $value;           $matcher.has-to = True }
      when 'by'           { $matcher.expected-by = $value;           $matcher.has-by = True }
      when 'at-least'     { $matcher.expected-by-at-least = $value;  $matcher.has-by-at-least = True }
      when 'at-most'      { $matcher.expected-by-at-most = $value;   $matcher.has-by-at-most = True }
    }
  }

  $matcher;
}

describe 'the change matcher running an action', {
  context 'given an action that changes the observed value', {
    let(:counter, { [0] });
    let(:matcher, { matcher-for({ counter()[0] }) });

    it 'matches', {
      expect(matcher().matches({ counter()[0]++ })).to.be-truthy;
    }

    it 'records the value from before the action', {
      matcher().matches({ counter()[0]++ });

      expect(matcher().before-value).to.be(0);
    }

    it 'records the value from after the action', {
      matcher().matches({ counter()[0]++ });

      expect(matcher().after-value).to.be(1);
    }

    it 'records that the action ran', {
      matcher().matches({ counter()[0]++ });

      expect(matcher().action-ran).to.be-truthy;
    }

    it 'reports the difference between the two values', {
      matcher().matches({ counter()[0] += 3 });

      expect(matcher().delta).to.be(3);
    }

    it 'starts over when it runs a second action', {
      matcher().matches({ counter()[0]++ });
      matcher().matches({ counter()[0]++ });

      expect(matcher().before-value).to.be(1);
    }
  }

  context 'given an action that leaves the observed value alone', {
    let(:matcher, { matcher-for({ 7 }) });

    it 'does not match', {
      expect(matcher().matches({ 'no change here' })).to.be-falsy;
    }

    it 'says the value stayed as it was', {
      matcher().matches({ 'no change here' });

      expect(matcher().failure-message({ }))
        .to.include('but it remained 7');
    }
  }

  context 'given something that is not a callable', {
    let(:matcher, { matcher-for({ 0 }) });

    it 'does not match', {
      expect(matcher().matches(42)).to.be-falsy;
    }

    it 'never runs an action', {
      matcher().matches(42);

      expect(matcher().action-ran).to.be-falsy;
    }

    it 'says a callable was expected', {
      matcher().matches(42);

      expect(matcher().failure-message(42)).to.eq('expected a Callable for change, but got 42');
    }
  }
}

describe 'the change matcher checking a bound', {
  let(:value, { [0] });

  context 'given a starting value that does not match from', {
    let(:matcher, { matcher-for({ value()[0] }, :from(9)) });

    before-each { matcher().matches({ value()[0]++ }) }

    it 'does not match', {
      expect(matcher().check-captured).to.be-falsy;
    }

    it 'reports the value it started from', {
      expect(matcher().failure-message({ })).to.include('but it started as 0');
    }
  }

  context 'given an ending value that does not match to', {
    let(:matcher, { matcher-for({ value()[0] }, :to(9)) });

    before-each { matcher().matches({ value()[0]++ }) }

    it 'reports the value it ended as', {
      expect(matcher().failure-message({ })).to.include('but it ended as 1');
    }
  }

  context 'given a change of the wrong size', {
    let(:matcher, { matcher-for({ value()[0] }, :by(5)) });

    before-each { matcher().matches({ value()[0] += 2 }) }

    it 'does not match', {
      expect(matcher().check-captured).to.be-falsy;
    }

    it 'reports the size of the change it saw', {
      expect(matcher().failure-message({ })).to.include('but it changed by 2');
    }

    it 'names the size it wanted', {
      expect(matcher().failure-message({ })).to.include('by 5');
    }
  }

  context 'given a change below the lower bound', {
    let(:matcher, { matcher-for({ value()[0] }, :at-least(5)) });

    before-each { matcher().matches({ value()[0] += 2 }) }

    it 'does not match', {
      expect(matcher().check-captured).to.be-falsy;
    }

    it 'names the bound it wanted', {
      expect(matcher().failure-message({ })).to.include('by at least 5');
    }
  }

  context 'given a change above the upper bound', {
    let(:matcher, { matcher-for({ value()[0] }, :at-most(1)) });

    before-each { matcher().matches({ value()[0] += 4 }) }

    it 'does not match', {
      expect(matcher().check-captured).to.be-falsy;
    }

    it 'names the bound it wanted', {
      expect(matcher().failure-message({ })).to.include('by at most 1');
    }
  }

  context 'given a size bound on values that are not numbers', {
    let(:words, { ['before'] });
    let(:matcher, { matcher-for({ words()[0] }, :by(1)) });

    before-each { matcher().matches({ words()[0] = 'after' }) }

    it 'does not match', {
      expect(matcher().check-captured).to.be-falsy;
    }

    it 'says the values were not numeric', {
      expect(matcher().failure-message({ })).to.include('but values were not numeric');
    }

    it 'shows both values it saw', {
      expect(matcher().failure-message({ })).to.include('(before: "before", after: "after")');
    }

    it 'reports no difference between them', {
      expect(matcher().delta).to.be(Nil);
    }
  }
}

describe 'the way the change matcher describes itself', {
  it 'describes an unbounded change', {
    expect(matcher-for({ 0 }).description).to.eq('change observable');
  }

  it 'describes a starting value', {
    expect(matcher-for({ 0 }, :from(1)).description).to.eq('change observable from 1');
  }

  it 'describes an ending value', {
    expect(matcher-for({ 0 }, :to(2)).description).to.eq('change observable to 2');
  }

  it 'describes a size', {
    expect(matcher-for({ 0 }, :by(3)).description).to.eq('change observable by 3');
  }

  it 'describes a lower bound', {
    expect(matcher-for({ 0 }, :at-least(4)).description)
      .to.eq('change observable by at least 4');
  }

  it 'describes an upper bound', {
    expect(matcher-for({ 0 }, :at-most(5)).description)
      .to.eq('change observable by at most 5');
  }

  it 'describes a change that was not wanted', {
    my $value = [0];
    my $observing = matcher-for({ $value[0] });
    $observing.matches({ $value[0] = 8 });

    expect($observing.failure-message-negated({ }))
      .to.eq('expected block not to change observable, but it changed from 0 to 8');
  }
}
