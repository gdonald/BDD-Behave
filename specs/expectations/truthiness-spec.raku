use BDD::Behave;
use BDD::Behave::Failures;

describe 'be-truthy matcher', {
  it 'passes for True', {
    expect(True).to.be-truthy;
  }

  it 'passes for a non-zero integer', {
    expect(1).to.be-truthy;
  }

  it 'passes for a negative integer', {
    expect(-1).to.be-truthy;
  }

  it 'passes for a non-empty string', {
    expect('hello').to.be-truthy;
  }

  it 'passes for a non-empty array', {
    expect([1, 2, 3]).to.be-truthy;
  }

  it 'passes for a non-empty hash', {
    expect({ a => 1 }).to.be-truthy;
  }

  it 'passes for a Rat', {
    expect(1.5).to.be-truthy;
  }

  it 'passes for a Num', {
    expect(3.14e0).to.be-truthy;
  }

  it 'fails for False', {
    Failures.list = ();
    expect(False).to.be-truthy;
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }

  it 'fails for 0', {
    Failures.list = ();
    expect(0).to.be-truthy;
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }

  it 'fails for an empty string', {
    Failures.list = ();
    expect('').to.be-truthy;
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }

  it q[passes for the string '0' (non-empty in Raku)], {
    expect('0').to.be-truthy;
  }

  it 'fails for an empty array', {
    Failures.list = ();
    expect([]).to.be-truthy;
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }

  it 'fails for an empty hash', {
    Failures.list = ();
    expect({}).to.be-truthy;
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }

  it 'fails for Nil', {
    Failures.list = ();
    expect(Nil).to.be-truthy;
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }

  it 'fails for an undefined type object', {
    Failures.list = ();
    expect(Int).to.be-truthy;
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }
}

describe 'be-falsy matcher', {
  it 'passes for False', {
    expect(False).to.be-falsy;
  }

  it 'passes for 0', {
    expect(0).to.be-falsy;
  }

  it 'passes for an empty string', {
    expect('').to.be-falsy;
  }

  it q[fails for the string '0' (non-empty in Raku)], {
    Failures.list = ();
    expect('0').to.be-falsy;
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }

  it 'passes for an empty array', {
    expect([]).to.be-falsy;
  }

  it 'passes for an empty hash', {
    expect({}).to.be-falsy;
  }

  it 'passes for Nil', {
    expect(Nil).to.be-falsy;
  }

  it 'passes for an undefined Int type object', {
    expect(Int).to.be-falsy;
  }

  it 'passes for Any', {
    expect(Any).to.be-falsy;
  }

  it 'fails for True', {
    Failures.list = ();
    expect(True).to.be-falsy;
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }

  it 'fails for 1', {
    Failures.list = ();
    expect(1).to.be-falsy;
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }

  it 'fails for a non-empty string', {
    Failures.list = ();
    expect('hello').to.be-falsy;
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }

  it 'fails for a non-empty array', {
    Failures.list = ();
    expect([1]).to.be-falsy;
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }
}

describe 'be-truthy negation', {
  it 'passes for a falsy value under .not', {
    expect(False).to.not.be-truthy;
    expect(0).to.not.be-truthy;
    expect('').to.not.be-truthy;
  }

  it 'fails for a truthy value under .not', {
    Failures.list = ();
    expect(True).to.not.be-truthy;
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }
}

describe 'be-falsy negation', {
  it 'passes for a truthy value under .not', {
    expect(True).to.not.be-falsy;
    expect(1).to.not.be-falsy;
    expect('hello').to.not.be-falsy;
  }

  it 'fails for a falsy value under .not', {
    Failures.list = ();
    expect(False).to.not.be-falsy;
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }
}

describe 'be-truthy failure messages', {
  it 'positive form names the actual value', {
    Failures.list = ();
    expect(0).to.be-truthy;
    my $message = Failures.list[0].message;
    Failures.list = ();
    expect($message).to.be('expected 0 to be truthy');
  }

  it 'negated form names the actual value', {
    Failures.list = ();
    expect(True).to.not.be-truthy;
    my $message = Failures.list[0].message;
    Failures.list = ();
    expect($message).to.be('expected Bool::True not to be truthy');
  }
}

describe 'be-falsy failure messages', {
  it 'positive form names the actual value', {
    Failures.list = ();
    expect(True).to.be-falsy;
    my $message = Failures.list[0].message;
    Failures.list = ();
    expect($message).to.be('expected Bool::True to be falsy');
  }

  it 'negated form names the actual value', {
    Failures.list = ();
    expect(False).to.not.be-falsy;
    my $message = Failures.list[0].message;
    Failures.list = ();
    expect($message).to.be('expected Bool::False not to be falsy');
  }
}

describe 'be-truthy and be-falsy preserve Failure tooling fields', {
  it 'preserves Failure.given for be-truthy', {
    Failures.list = ();
    expect(0).to.be-truthy;
    my $given = Failures.list[0].given;
    Failures.list = ();
    expect($given).to.be(0);
  }

  it 'preserves Failure.given for be-falsy', {
    Failures.list = ();
    expect(42).to.be-falsy;
    my $given = Failures.list[0].given;
    Failures.list = ();
    expect($given).to.be(42);
  }

  it 'marks negated failures as negated', {
    Failures.list = ();
    expect(True).to.not.be-truthy;
    my $negated = Failures.list[0].negated;
    Failures.list = ();
    expect($negated).to.be-truthy;
  }
}
