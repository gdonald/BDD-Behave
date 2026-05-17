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
    Failures.list = ();
    expect('abc').to.match(/\d+/);
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }

  it 'records a matcher-supplied failure message', {
    Failures.list = ();
    expect('abc').to.match(/\d+/);
    my $message = Failures.list[0].message;
    Failures.list = ();
    expect($message).to.be('expected "abc" to match /\d+/');
  }

  it 'negation passes when the string does not match', {
    expect('abc').to.not.match(/\d+/);
  }

  it 'negation fails when the string matches', {
    Failures.list = ();
    expect('abc123').to.not.match(/\d+/);
    my $count   = Failures.list.elems;
    my $message = Failures.list[0].message;
    my $negated = Failures.list[0].negated;
    Failures.list = ();
    expect($count).to.be(1);
    expect($message).to.be('expected "abc123" not to match /\d+/');
    expect($negated).to.be-truthy;
  }
}

describe 'match matcher edge cases', {
  it 'fails on undefined actual', {
    Failures.list = ();
    expect(Str).to.match(/\d+/);
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }

  it 'fails on Any actual', {
    Failures.list = ();
    expect(Any).to.match(/foo/);
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }

  it 'fails on non-Str actual (Int)', {
    Failures.list = ();
    expect(123).to.match(/\d+/);
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }

  it 'fails on non-Str actual (Array)', {
    Failures.list = ();
    expect([1, 2, 3]).to.match(/\d+/);
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }

  it 'preserves Failure.given and Failure.expected for tooling', {
    Failures.list = ();
    expect('abc').to.match(/\d+/);
    expect(Failures.list[0].given).to.be('abc');
    expect(Failures.list[0].expected).to.be-a(Regex);
    expect(Failures.list[0].expected.raku).to.eq(/\d+/.raku);
    Failures.list = ();
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
