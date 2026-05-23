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
    my @captured = capture-failures {
      expect(42).to.be-nil;
    };
    expect(@captured.elems).to.be(1);
  }

  it 'fails for zero (a defined integer)', {
    my @captured = capture-failures {
      expect(0).to.be-nil;
    };
    expect(@captured.elems).to.be(1);
  }

  it 'fails for an empty string', {
    my @captured = capture-failures {
      expect('').to.be-nil;
    };
    expect(@captured.elems).to.be(1);
  }

  it 'fails for an empty array', {
    my @captured = capture-failures {
      expect([]).to.be-nil;
    };
    expect(@captured.elems).to.be(1);
  }

  it 'fails for an empty hash', {
    my @captured = capture-failures {
      expect({}).to.be-nil;
    };
    expect(@captured.elems).to.be(1);
  }

  it 'fails for False (a defined Bool)', {
    my @captured = capture-failures {
      expect(False).to.be-nil;
    };
    expect(@captured.elems).to.be(1);
  }

  it 'fails for a defined instance of a user-defined class', {
    my class Widget {}
    my @captured = capture-failures {
      expect(Widget.new).to.be-nil;
    };
    expect(@captured.elems).to.be(1);
  }
}

describe 'be-nil negation', {
  it 'passes for a defined value under .not', {
    expect(42).to.not.be-nil;
    expect('hello').to.not.be-nil;
    expect([1, 2]).to.not.be-nil;
  }

  it 'fails for Nil under .not', {
    my @captured = capture-failures {
      expect(Nil).to.not.be-nil;
    };
    expect(@captured.elems).to.be(1);
  }

  it 'fails for an undefined type object under .not', {
    my @captured = capture-failures {
      expect(Int).to.not.be-nil;
    };
    expect(@captured.elems).to.be(1);
  }
}

describe 'be-nil failure messages', {
  it 'positive form names the actual value', {
    my @captured = capture-failures {
      expect(42).to.be-nil;
    };
    my $message = @captured[0].message;
    expect($message).to.be('expected 42 to be nil');
  }

  it 'positive form renders empty string actual', {
    my @captured = capture-failures {
      expect('').to.be-nil;
    };
    my $message = @captured[0].message;
    expect($message).to.be(q[expected "" to be nil]);
  }

  it 'negated form names the actual value', {
    my @captured = capture-failures {
      expect(Int).to.not.be-nil;
    };
    my $message = @captured[0].message;
    expect($message).to.be('expected Int not to be nil');
  }
}

describe 'be-nil preserves Failure tooling fields', {
  it 'preserves Failure.given for be-nil', {
    my @captured = capture-failures {
      expect(42).to.be-nil;
    };
    my $given = @captured[0].given;
    expect($given).to.be(42);
  }

  it 'marks negated failures as negated', {
    my @captured = capture-failures {
      expect(Nil).to.not.be-nil;
    };
    my $negated = @captured[0].negated;
    expect($negated).to.be-truthy;
  }
}
