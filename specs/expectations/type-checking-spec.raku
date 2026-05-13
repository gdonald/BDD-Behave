use BDD::Behave;
use BDD::Behave::Failures;

class Animal {}
class Dog is Animal {}
class Poodle is Dog {}

role Walkable {
  method walk { 'walking' }
}

class Bird does Walkable {}

subset Positive of Int where * > 0;

describe 'be-a matcher with built-in types', {
  it 'passes for matching primitive type', {
    expect(42).to.be-a(Int);
  }

  it 'passes for Str', {
    expect('hello').to.be-a(Str);
  }

  it 'passes for Array', {
    expect([1, 2, 3]).to.be-a(Array);
  }

  it 'passes for Hash', {
    expect({ a => 1 }).to.be-a(Hash);
  }

  it 'passes for parent type via inheritance', {
    expect(42).to.be-a(Numeric);
  }

  it 'passes for Cool (Int is Cool)', {
    expect(42).to.be-a(Cool);
  }

  it 'fails for mismatched type', {
    Failures.list = ();
    expect('hello').to.be-a(Int);
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }
}

describe 'be-a matcher with user classes', {
  it 'passes for the exact class', {
    expect(Animal.new).to.be-a(Animal);
  }

  it 'passes for a subclass against its parent', {
    expect(Dog.new).to.be-a(Animal);
  }

  it 'passes for a grandchild class against its grandparent', {
    expect(Poodle.new).to.be-a(Animal);
  }

  it 'passes for a subclass against the immediate parent', {
    expect(Poodle.new).to.be-a(Dog);
  }

  it 'fails when parent instance is checked against a subclass', {
    Failures.list = ();
    expect(Animal.new).to.be-a(Dog);
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }

  it 'fails when sibling classes are compared', {
    Failures.list = ();
    expect(Dog.new).to.be-a(Bird);
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }
}

describe 'be-a matcher with roles', {
  it 'passes when the object does the role', {
    expect(Bird.new).to.be-a(Walkable);
  }

  it 'fails when the object does not do the role', {
    Failures.list = ();
    expect(Animal.new).to.be-a(Walkable);
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }
}

describe 'be-a matcher with subsets', {
  it 'passes when the value satisfies the subset', {
    expect(5).to.be-a(Positive);
  }

  it 'fails when the value does not satisfy the subset', {
    Failures.list = ();
    expect(-1).to.be-a(Positive);
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }
}

describe 'be-an matcher (alias for be-a)', {
  it 'works the same as be-a', {
    expect(42).to.be-an(Int);
  }

  it 'fails for mismatched type via be-an', {
    Failures.list = ();
    expect('hi').to.be-an(Int);
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }
}

describe 'be-a matcher negation', {
  it 'passes negation when types do not match', {
    expect('hi').to.not.be-a(Int);
  }

  it 'fails negation when types match', {
    Failures.list = ();
    expect(42).to.not.be-a(Int);
    my $message = Failures.list[0].message;
    Failures.list = ();
    expect($message).to.include('not to be a Int');
  }
}

describe 'be-a matcher failure metadata', {
  it 'sets Failure.given and Failure.expected', {
    Failures.list = ();
    expect('hi').to.be-a(Int);
    my $given    = Failures.list[0].given;
    my $expected = Failures.list[0].expected;
    Failures.list = ();
    expect($given).to.be('hi');
    expect($expected === Int).to.be-truthy;
  }
}

describe 'be-an-instance-of matcher', {
  it 'passes for the exact class', {
    expect(Dog.new).to.be-an-instance-of(Dog);
  }

  it 'fails when checking a subclass against its parent', {
    Failures.list = ();
    expect(Dog.new).to.be-an-instance-of(Animal);
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }

  it 'fails when checking a parent instance against a subclass', {
    Failures.list = ();
    expect(Animal.new).to.be-an-instance-of(Dog);
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }

  it 'passes for built-in types', {
    expect(42).to.be-an-instance-of(Int);
    expect('hi').to.be-an-instance-of(Str);
  }

  it 'fails when checking against a parent built-in type', {
    Failures.list = ();
    expect(42).to.be-an-instance-of(Numeric);
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }

  it 'fails for an undefined type object', {
    Failures.list = ();
    expect(Int).to.be-an-instance-of(Int);
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }

  it 'fails when comparing against a role (no class has WHAT === Role)', {
    Failures.list = ();
    expect(Bird.new).to.be-an-instance-of(Walkable);
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }

  it 'fails when comparing against a subset', {
    Failures.list = ();
    expect(5).to.be-an-instance-of(Positive);
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }
}

describe 'be-an-instance-of matcher negation', {
  it 'passes negation when types differ', {
    expect(Dog.new).to.not.be-an-instance-of(Animal);
  }

  it 'fails negation when types match exactly', {
    Failures.list = ();
    expect(Dog.new).to.not.be-an-instance-of(Dog);
    my $message = Failures.list[0].message;
    Failures.list = ();
    expect($message).to.include('not to be an instance of Dog');
  }
}

describe 'be-an-instance-of failure message', {
  it 'reports the expected type in the message', {
    Failures.list = ();
    expect(Animal.new).to.be-an-instance-of(Dog);
    my $message = Failures.list[0].message;
    Failures.list = ();
    expect($message).to.include('to be an instance of Dog');
  }
}
