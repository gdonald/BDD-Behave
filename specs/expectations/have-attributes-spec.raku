use BDD::Behave;
use BDD::Behave::Failures;
use BDD::Behave::Matcher;

class HAPoint {
  has $.x;
  has $.y;
}

class HAPerson {
  has Str $.name;
  has Int $.age;
}

role HAColoured {
  has Str $.colour;
}

class HAShape does HAColoured {
  has Int $.sides;
}

describe 'have-attributes matcher passes', {
  it 'passes when a single attribute matches', {
    expect(HAPoint.new(:x(1), :y(2))).to.have-attributes(:x(1));
  }

  it 'passes when multiple attributes all match', {
    expect(HAPoint.new(:x(1), :y(2))).to.have-attributes(:x(1), :y(2));
  }

  it 'passes for string and int attributes together', {
    expect(HAPerson.new(:name<Alice>, :age(30)))
      .to.have-attributes(:name<Alice>, :age(30));
  }

  it 'passes for role-supplied attributes', {
    expect(HAShape.new(:colour<red>, :sides(3)))
      .to.have-attributes(:colour<red>, :sides(3));
  }
}

describe 'have-attributes matcher fails', {
  it 'fails when a single attribute differs', {
    Failures.list = ();
    expect(HAPoint.new(:x(1), :y(2))).to.have-attributes(:x(99));
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }

  it 'fails when any one of multiple attributes differs', {
    Failures.list = ();
    expect(HAPoint.new(:x(1), :y(2))).to.have-attributes(:x(1), :y(99));
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }

  it 'fails when the attribute does not exist on the object', {
    Failures.list = ();
    expect(HAPoint.new(:x(1), :y(2))).to.have-attributes(:nonexistent(1));
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }
}

describe 'have-attributes matcher composes with other matchers', {
  it 'accepts a matcher as the attribute value', {
    expect(HAPoint.new(:x(30), :y(0)))
      .to.have-attributes(:x(BeAMatcher.new(:type(Int))));
  }

  it 'fails when the composed inner matcher rejects the value', {
    Failures.list = ();
    expect(HAPoint.new(:x('hello'), :y(0)))
      .to.have-attributes(:x(BeAMatcher.new(:type(Int))));
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }
}

describe 'have-attributes negation', {
  it 'passes negation when a value differs', {
    expect(HAPoint.new(:x(1), :y(2))).to.not.have-attributes(:x(99));
  }

  it 'fails negation when all values match', {
    Failures.list = ();
    expect(HAPoint.new(:x(1), :y(2))).to.not.have-attributes(:x(1));
    my $message = Failures.list[0].message;
    Failures.list = ();
    expect($message).to.include('not to have attributes');
  }
}

describe 'have-attributes failure messages', {
  it 'lists missing accessors when the object does not respond', {
    Failures.list = ();
    expect(HAPoint.new(:x(1), :y(2))).to.have-attributes(:foo(1));
    my $message = Failures.list[0].message;
    Failures.list = ();
    expect($message).to.include('missing:');
    expect($message).to.include('"foo"');
  }

  it 'shows actual and expected values for mismatched attributes', {
    Failures.list = ();
    expect(HAPoint.new(:x(1), :y(2))).to.have-attributes(:x(99));
    my $message = Failures.list[0].message;
    Failures.list = ();
    expect($message).to.include('mismatched:');
    expect($message).to.include('got 1');
    expect($message).to.include('wanted 99');
  }

  it 'reports both missing and mismatched in the same failure', {
    Failures.list = ();
    expect(HAPoint.new(:x(1), :y(2))).to.have-attributes(:x(99), :foo(1));
    my $message = Failures.list[0].message;
    Failures.list = ();
    expect($message).to.include('missing:');
    expect($message).to.include('mismatched:');
  }
}

describe 'have-attributes arity', {
  it 'dies when called without any pairs', {
    my $caught;
    try {
      expect(HAPoint.new(:x(1), :y(2))).to.have-attributes();
      CATCH {
        default { $caught = .message }
      }
    }
    expect($caught).to.include('have-attributes requires at least one');
  }
}

describe 'have-attributes failure metadata', {
  it 'sets Failure.given and Failure.expected', {
    Failures.list = ();
    expect(HAPoint.new(:x(1), :y(2))).to.have-attributes(:x(99));
    my $given    = Failures.list[0].given;
    my $expected = Failures.list[0].expected;
    Failures.list = ();
    expect($given).to.be-a(HAPoint);
    expect($expected<x>).to.be(99);
  }
}
