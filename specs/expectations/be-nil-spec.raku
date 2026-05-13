use BDD::Behave;
use BDD::Behave::Failures;

describe 'be-nil matcher', {
  it 'passes for Nil', {
    expect(Nil).to.be-nil;
  }

  it 'passes for Any', {
    expect(Any).to.be-nil;
  }

  it 'passes for an undefined Int type object', {
    expect(Int).to.be-nil;
  }

  it 'passes for an undefined Str type object', {
    expect(Str).to.be-nil;
  }

  it 'passes for an undefined user-defined class', {
    my class Widget {}
    expect(Widget).to.be-nil;
  }

  it 'fails for a defined integer', {
    Failures.list = ();
    expect(42).to.be-nil;
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }

  it 'fails for zero (a defined integer)', {
    Failures.list = ();
    expect(0).to.be-nil;
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }

  it 'fails for an empty string', {
    Failures.list = ();
    expect('').to.be-nil;
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }

  it 'fails for an empty array', {
    Failures.list = ();
    expect([]).to.be-nil;
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }

  it 'fails for an empty hash', {
    Failures.list = ();
    expect({}).to.be-nil;
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }

  it 'fails for False (a defined Bool)', {
    Failures.list = ();
    expect(False).to.be-nil;
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }

  it 'fails for a defined instance of a user-defined class', {
    my class Widget {}
    Failures.list = ();
    expect(Widget.new).to.be-nil;
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }
}

describe 'be-nil negation', {
  it 'passes for a defined value under .not', {
    expect(42).to.not.be-nil;
    expect('hello').to.not.be-nil;
    expect([1, 2]).to.not.be-nil;
  }

  it 'fails for Nil under .not', {
    Failures.list = ();
    expect(Nil).to.not.be-nil;
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }

  it 'fails for an undefined type object under .not', {
    Failures.list = ();
    expect(Int).to.not.be-nil;
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }
}

describe 'be-nil failure messages', {
  it 'positive form names the actual value', {
    Failures.list = ();
    expect(42).to.be-nil;
    my $message = Failures.list[0].message;
    Failures.list = ();
    expect($message).to.be('expected 42 to be nil');
  }

  it 'positive form renders empty string actual', {
    Failures.list = ();
    expect('').to.be-nil;
    my $message = Failures.list[0].message;
    Failures.list = ();
    expect($message).to.be(q[expected "" to be nil]);
  }

  it 'negated form names the actual value', {
    Failures.list = ();
    expect(Int).to.not.be-nil;
    my $message = Failures.list[0].message;
    Failures.list = ();
    expect($message).to.be('expected Int not to be nil');
  }
}

describe 'be-nil preserves Failure tooling fields', {
  it 'preserves Failure.given for be-nil', {
    Failures.list = ();
    expect(42).to.be-nil;
    my $given = Failures.list[0].given;
    Failures.list = ();
    expect($given).to.be(42);
  }

  it 'marks negated failures as negated', {
    Failures.list = ();
    expect(Nil).to.not.be-nil;
    my $negated = Failures.list[0].negated;
    Failures.list = ();
    expect($negated).to.be-truthy;
  }
}
