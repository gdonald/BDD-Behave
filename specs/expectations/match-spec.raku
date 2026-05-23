use BDD::Behave;
use BDD::Behave::Failures;

describe 'match matcher on strings', {
  it 'matches a simple digit pattern', {
    expect('abc123').to.match(/\d+/);
  }

  it 'matches a word pattern', {
    expect('hello world').to.match(/world/);
  }

  it 'matches anchored regex', {
    expect('hello').to.match(/^hello$/);
  }

  it 'matches a character class', {
    expect('foo42').to.match(/<[0..9]>+/);
  }

  it 'matches alternation', {
    expect('cat').to.match(/cat | dog/);
  }

  it 'fails when the string does not match', {
    my @captured = capture-failures {
      expect('abc').to.match(/\d+/);
    };
    expect(@captured.elems).to.be(1);
  }

  it 'records a matcher-supplied failure message', {
    my @captured = capture-failures {
      expect('abc').to.match(/\d+/);
    };
    my $message = @captured[0].message;
    expect($message).to.be('expected "abc" to match /\d+/');
  }

  it 'negation passes when the string does not match', {
    expect('abc').to.not.match(/\d+/);
  }

  it 'negation fails when the string matches', {
    my @captured = capture-failures {
      expect('abc123').to.not.match(/\d+/);
    };
    my $count   = @captured.elems;
    my $message = @captured[0].message;
    my $negated = @captured[0].negated;
    expect($count).to.be(1);
    expect($message).to.be('expected "abc123" not to match /\d+/');
    expect($negated).to.be-truthy;
  }
}

describe 'match matcher edge cases', {
  it 'fails on undefined actual', {
    my @captured = capture-failures {
      expect(Str).to.match(/\d+/);
    };
    expect(@captured.elems).to.be(1);
  }

  it 'fails on Any actual', {
    my @captured = capture-failures {
      expect(Any).to.match(/foo/);
    };
    expect(@captured.elems).to.be(1);
  }

  it 'fails on non-Str actual (Int)', {
    my @captured = capture-failures {
      expect(123).to.match(/\d+/);
    };
    expect(@captured.elems).to.be(1);
  }

  it 'fails on non-Str actual (Array)', {
    my @captured = capture-failures {
      expect([1, 2, 3]).to.match(/\d+/);
    };
    expect(@captured.elems).to.be(1);
  }

  it 'preserves Failure.given and Failure.expected for tooling', {
    my @captured = capture-failures {
      expect('abc').to.match(/\d+/);
    };
    expect(@captured[0].given).to.be('abc');
    expect(@captured[0].expected).to.be-a(Regex);
    expect(@captured[0].expected.raku).to.eq(/\d+/.raku);
  }
}

describe 'match matcher with rx// syntax', {
  it 'matches using rx// quoted regex', {
    expect('foo bar').to.match(rx/bar/);
  }

  it 'matches with case-insensitive modifier', {
    expect('HELLO').to.match(rx:i/hello/);
  }
}
