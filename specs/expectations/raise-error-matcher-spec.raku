use BDD::Behave;
use BDD::Behave::Matcher::Exception;

my class X::Sample is Exception {
  method message { 'sample failure' }
}

# The expectation builder drives this matcher through its captured state, so
# the matcher's own `matches` is exercised here directly.
sub matcher-for(--> RaiseErrorMatcher) { RaiseErrorMatcher.new }

sub matcher-for-type(Mu \type --> RaiseErrorMatcher) {
  RaiseErrorMatcher.new(:expected-type(type), :has-type);
}

sub matcher-for-message($message --> RaiseErrorMatcher) {
  RaiseErrorMatcher.new(:expected-message($message));
}

describe 'the raise-error matcher running a block', {
  context 'given a block that raises', {
    let(:matcher, { matcher-for() });

    it 'matches', {
      expect(matcher().matches({ die 'boom' })).to.be-truthy;
    }

    it 'keeps the exception it caught', {
      matcher().matches({ die 'boom' });

      expect(matcher().raised-exception.message).to.eq('boom');
    }

    it 'forgets the previous exception when it runs again', {
      matcher().matches({ die 'boom' });
      matcher().matches({ 'quiet' });

      expect(matcher().raised-exception.defined).to.be-falsy;
    }
  }

  context 'given a block that raises nothing', {
    let(:matcher, { matcher-for() });

    it 'does not match', {
      expect(matcher().matches({ 'quiet' })).to.be-falsy;
    }

    it 'says nothing was raised', {
      matcher().matches({ 'quiet' });

      expect(matcher().failure-message({ }))
        .to.eq('expected block to raise an error, but none was raised');
    }
  }

  context 'given something that is not a callable', {
    let(:matcher, { matcher-for() });

    it 'does not match', {
      expect(matcher().matches(42)).to.be-falsy;
    }

    it 'says a callable was expected', {
      matcher().matches(42);

      expect(matcher().failure-message(42)).to.eq('expected a Callable, but got 42');
    }
  }
}

describe 'the raise-error matcher checking the exception it caught', {
  context 'given a type that does not match', {
    let(:matcher, { matcher-for-type(X::Sample) });

    before-each { matcher().matches({ die 'boom' }) }

    it 'does not match', {
      expect(matcher().check-captured).to.be-falsy;
    }

    it 'reports what was raised instead', {
      expect(matcher().failure-message({ })).to.include('but raised X::AdHoc: boom');
    }

    it 'names the type it wanted', {
      expect(matcher().failure-message({ })).to.include('raise X::Sample');
    }
  }

  context 'given a type that matches', {
    it 'matches', {
      expect(matcher-for-type(X::Sample).matches({ X::Sample.new.throw })).to.be-truthy;
    }
  }

  context 'given a message that does not match', {
    let(:matcher, { matcher-for-message('expected text') });

    before-each { matcher().matches({ die 'other text' }) }

    it 'does not match', {
      expect(matcher().check-captured).to.be-falsy;
    }

    it 'names the message it wanted', {
      expect(matcher().failure-message({ }))
        .to.include('with message "expected text"');
    }

    it 'reports the message it got', {
      expect(matcher().failure-message({ })).to.include('but raised X::AdHoc: other text');
    }
  }

  context 'given a message that matches exactly', {
    it 'matches', {
      expect(matcher-for-message('boom').matches({ die 'boom' })).to.be-truthy;
    }
  }

  context 'given a message pattern that matches', {
    it 'matches', {
      expect(matcher-for-message(/'oo'/).matches({ die 'boom' })).to.be-truthy;
    }
  }

  context 'given a message pattern that does not match', {
    let(:matcher, { matcher-for-message(/'nothing like it'/) });

    before-each { matcher().matches({ die 'boom' }) }

    it 'does not match', {
      expect(matcher().check-captured).to.be-falsy;
    }

    it 'names the pattern it wanted', {
      expect(matcher().failure-message({ })).to.include('with message matching');
    }
  }
}

describe 'the way the raise-error matcher describes itself', {
  it 'describes any error', {
    expect(matcher-for().description).to.eq('raise an error');
  }

  it 'describes a type', {
    expect(matcher-for-type(X::Sample).description).to.eq('raise X::Sample');
  }

  it 'describes a message', {
    expect(matcher-for-message('boom').description)
      .to.eq('raise an error with message "boom"');
  }

  it 'reports the type as the value it expected', {
    expect(matcher-for-type(X::Sample).expected-value).to.be(X::Sample);
  }

  it 'reports the message as the value it expected when no type was given', {
    expect(matcher-for-message('boom').expected-value).to.eq('boom');
  }

  it 'reports no expected value when neither was given', {
    expect(matcher-for().expected-value).to.be(Nil);
  }

  it 'falls back to its description when nothing was missed', {
    my $matcher = matcher-for();
    $matcher.matches({ die 'boom' });

    expect($matcher.failure-message({ })).to.eq('expected block to raise an error');
  }

  it 'describes an error that was not wanted', {
    my $matcher = matcher-for();
    $matcher.matches({ die 'boom' });

    expect($matcher.failure-message-negated({ }))
      .to.eq('expected block not to raise an error, but one was raised (X::AdHoc: boom)');
  }

  it 'describes an error that was not wanted when none was caught', {
    expect(matcher-for().failure-message-negated({ }))
      .to.eq('expected block not to raise an error, but one was raised');
  }
}
