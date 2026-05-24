use BDD::Behave;
use BDD::Behave::Failures;
use BDD::Behave::Matcher;
use BDD::Behave::Matcher::Type;

my class Point {
  has $.x;
  has $.y;
}

my class Person {
  has Str $.name;
  has Int $.age;
}

my role Coloured {
  has Str $.colour;
}

my class Shape does Coloured {
  has Int $.sides;
}

describe 'have-attributes matcher passes', {
  it 'passes when a single attribute matches', {
    expect(Point.new(:x(1), :y(2))).to.have-attributes(:x(1));
  }

  it 'passes when multiple attributes all match', {
    expect(Point.new(:x(1), :y(2))).to.have-attributes(:x(1), :y(2));
  }

  it 'passes for string and int attributes together', {
    expect(Person.new(:name<Alice>, :age(30)))
      .to.have-attributes(:name<Alice>, :age(30));
  }

  it 'passes for role-supplied attributes', {
    expect(Shape.new(:colour<red>, :sides(3)))
      .to.have-attributes(:colour<red>, :sides(3));
  }
}

describe 'have-attributes matcher fails', {
  it 'fails when a single attribute differs', {
    my @captured = capture-failures {
      expect(Point.new(:x(1), :y(2))).to.have-attributes(:x(99));
    };
    expect(@captured.elems).to.be(1);
  }

  it 'fails when any one of multiple attributes differs', {
    my @captured = capture-failures {
      expect(Point.new(:x(1), :y(2))).to.have-attributes(:x(1), :y(99));
    };
    expect(@captured.elems).to.be(1);
  }

  it 'fails when the attribute does not exist on the object', {
    my @captured = capture-failures {
      expect(Point.new(:x(1), :y(2))).to.have-attributes(:nonexistent(1));
    };
    expect(@captured.elems).to.be(1);
  }
}

describe 'have-attributes matcher composes with other matchers', {
  it 'accepts a matcher as the attribute value', {
    expect(Point.new(:x(30), :y(0)))
      .to.have-attributes(:x(BeAMatcher.new(:type(Int))));
  }

  it 'fails when the composed inner matcher rejects the value', {
    my @captured = capture-failures {
      expect(Point.new(:x('hello'), :y(0)))
        .to.have-attributes(:x(BeAMatcher.new(:type(Int))));
    };
    expect(@captured.elems).to.be(1);
  }
}

describe 'have-attributes negation', {
  it 'passes negation when a value differs', {
    expect(Point.new(:x(1), :y(2))).to.not.have-attributes(:x(99));
  }

  it 'fails negation when all values match', {
    my @captured = capture-failures {
      expect(Point.new(:x(1), :y(2))).to.not.have-attributes(:x(1));
    };
    my $message = @captured[0].message;
    expect($message).to.include('not to have attributes');
  }
}

describe 'have-attributes failure messages', {
  it 'lists missing accessors when the object does not respond', {
    my @captured = capture-failures {
      expect(Point.new(:x(1), :y(2))).to.have-attributes(:foo(1));
    };
    my $message = @captured[0].message;
    expect($message).to.include('missing:');
    expect($message).to.include('"foo"');
  }

  it 'shows actual and expected values for mismatched attributes', {
    my @captured = capture-failures {
      expect(Point.new(:x(1), :y(2))).to.have-attributes(:x(99));
    };
    my $message = @captured[0].message;
    expect($message).to.include('mismatched:');
    expect($message).to.include('got 1');
    expect($message).to.include('wanted 99');
  }

  it 'reports both missing and mismatched in the same failure', {
    my @captured = capture-failures {
      expect(Point.new(:x(1), :y(2))).to.have-attributes(:x(99), :foo(1));
    };
    my $message = @captured[0].message;
    expect($message).to.include('missing:');
    expect($message).to.include('mismatched:');
  }
}

describe 'have-attributes arity', {
  it 'dies when called without any pairs', {
    my $caught;
    try {
      expect(Point.new(:x(1), :y(2))).to.have-attributes();
      CATCH {
        default { $caught = .message }
      }
    }
    expect($caught).to.include('have-attributes requires at least one');
  }
}

describe 'have-attributes failure metadata', {
  it 'sets Failure.given and Failure.expected', {
    my @captured = capture-failures {
      expect(Point.new(:x(1), :y(2))).to.have-attributes(:x(99));
    };
    my $given    = @captured[0].given;
    my $expected = @captured[0].expected;
    expect($given).to.be-a(Point);
    expect($expected<x>).to.be(99);
  }
}
