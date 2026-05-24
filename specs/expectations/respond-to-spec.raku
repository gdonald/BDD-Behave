use BDD::Behave;
use BDD::Behave::Failures;

my class Calculator {
  method add($a, $b) { $a + $b }
  method subtract($a, $b) { $a - $b }
}

my role Greeter {
  method greet { 'hello' }
}

my class Person does Greeter {
  method name { 'Alice' }
}

my class Dog {
  method bark { 'woof' }
}

describe 'respond-to matcher with user classes', {
  it 'passes when instance has the method', {
    expect(Calculator.new).to.respond-to('add');
  }

  it 'passes when type object has the method', {
    expect(Calculator).to.respond-to('add');
  }

  it 'passes when checking multiple methods', {
    expect(Calculator.new).to.respond-to('add', 'subtract');
  }

  it 'passes for methods from composed roles', {
    expect(Person.new).to.respond-to('greet');
  }

  it 'passes for own methods alongside role methods', {
    expect(Person.new).to.respond-to('name', 'greet');
  }

  it 'fails when method is missing', {
    my @captured = capture-failures {
      expect(Calculator.new).to.respond-to('multiply');
    };
    expect(@captured.elems).to.be(1);
  }

  it 'fails when any one of multiple methods is missing', {
    my @captured = capture-failures {
      expect(Dog.new).to.respond-to('bark', 'meow');
    };
    expect(@captured.elems).to.be(1);
  }
}

describe 'respond-to matcher with built-in types', {
  it 'passes for Str methods', {
    expect('hello').to.respond-to('uc', 'lc', 'chars');
  }

  it 'passes for Array methods', {
    expect([1, 2, 3]).to.respond-to('push', 'pop', 'elems');
  }

  it 'passes for Hash methods', {
    expect({ a => 1 }).to.respond-to('keys', 'values');
  }

  it 'fails for a method built-ins do not have', {
    my @captured = capture-failures {
      expect('hello').to.respond-to('totally-not-a-method');
    };
    expect(@captured.elems).to.be(1);
  }
}

describe 'respond-to matcher negation', {
  it 'passes negation when method is missing', {
    expect(Dog.new).to.not.respond-to('meow');
  }

  it 'fails negation when method exists', {
    my @captured = capture-failures {
      expect(Dog.new).to.not.respond-to('bark');
    };
    my $message = @captured[0].message;
    expect($message).to.include('not to respond to');
  }
}

describe 'respond-to failure messages', {
  it 'lists missing methods in the failure message', {
    my @captured = capture-failures {
      expect(Dog.new).to.respond-to('bark', 'meow', 'sit');
    };
    my $message = @captured[0].message;
    expect($message).to.include('missing:');
    expect($message).to.include('"meow"');
    expect($message).to.include('"sit"');
  }

  it 'mentions the expected method names', {
    my @captured = capture-failures {
      expect(Dog.new).to.respond-to('purr');
    };
    my $message = @captured[0].message;
    expect($message).to.include('to respond to');
    expect($message).to.include('"purr"');
  }
}

describe 'respond-to matcher arity', {
  it 'dies when called without arguments', {
    my $caught;
    try {
      expect(Calculator.new).to.respond-to();
      CATCH {
        default { $caught = .message }
      }
    }
    expect($caught).to.include('respond-to requires at least one method name');
  }
}

describe 'respond-to failure metadata', {
  it 'sets Failure.given and Failure.expected', {
    my @captured = capture-failures {
      expect(Dog.new).to.respond-to('meow');
    };
    my $given    = @captured[0].given;
    my $expected = @captured[0].expected;
    expect($given).to.be-a(Dog);
    expect($expected).to.include('meow');
  }
}
