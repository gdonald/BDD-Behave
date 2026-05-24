use BDD::Behave;

my class AllowGreeter {
  method hello($name) { "hello, $name" }
  method bye          { 'bye'         }
}

my class AllowRepo {
  method find($id) { "real:$id" }
}

describe 'allow(instance).to.receive(method).and-return(value)', :order<defined>, {
  it 'stubs only the targeted instance', {
    my $a = AllowGreeter.new;
    my $b = AllowGreeter.new;

    allow($a).to.receive('hello').and-return('STUB');

    expect($a.hello('alice')).to.be('STUB');
    expect($b.hello('bob')).to.be('hello, bob');
  }

  it 'returns Any when no .and-return is provided', {
    my $g = AllowGreeter.new;
    allow($g).to.receive('hello');
    expect($g.hello('x')).to.be(Any);
  }

  it 'restores the original method after the example via auto-cleanup', {
    my $g = AllowGreeter.new;
    allow($g).to.receive('hello').and-return('STUB');
    expect($g.hello('a')).to.be('STUB');
  }

  it 'no longer sees the stub from the previous example', {
    my $g = AllowGreeter.new;
    expect($g.hello('a')).to.be('hello, a');
  }
}

describe 'allow(class).to.receive(method)', :order<defined>, {
  it 'stubs dispatch through the class itself', {
    allow(AllowRepo).to.receive('find').and-return('mocked');
    expect(AllowRepo.find(42)).to.be('mocked');
  }

  it 'restores the class method after the example', {
    expect(AllowRepo.find(7)).to.be('real:7');
  }
}

describe 'and-raise', {
  it 'raises the supplied exception when the stubbed method is called', {
    my $g = AllowGreeter.new;
    allow($g).to.receive('bye').and-raise(X::AdHoc.new(payload => 'boom'));

    my $msg = '';
    try { $g.bye; CATCH { default { $msg = .message } } }
    expect($msg).to.be('boom');
  }
}

describe 'and-call-original', {
  it 'delegates back to the real implementation', {
    my $g = AllowGreeter.new;
    allow($g).to.receive('hello').and-return('overridden');
    expect($g.hello('alice')).to.be('overridden');

    allow($g).to.receive('hello').and-call-original;
    expect($g.hello('alice')).to.be('hello, alice');
  }
}

describe 'and-do', {
  it 'invokes the callable with the call args', {
    my $g = AllowGreeter.new;
    allow($g).to.receive('hello').and-do(-> $n { "STUB($n)" });
    expect($g.hello('zoe')).to.be('STUB(zoe)');
  }
}

describe 'replacement semantics', {
  it 'a second allow on the same target+method replaces the first', {
    my $g = AllowGreeter.new;
    allow($g).to.receive('hello').and-return('first');
    allow($g).to.receive('hello').and-return('second');

    expect($g.hello('x')).to.be('second');
  }
}

describe 'verification', {
  it 'rejects stubbing a method the class does not have', {
    my $g = AllowGreeter.new;
    my $died = False;
    try {
      allow($g).to.receive('imaginary');
      CATCH { default { $died = True } }
    }
    expect($died).to.be-truthy;
  }

  it 'rejects stubbing a non-existent class method', {
    my $died = False;
    try {
      allow(AllowRepo).to.receive('imaginary');
      CATCH { default { $died = True } }
    }
    expect($died).to.be-truthy;
  }
}

describe 'allow on a Double', {
  it 'routes through the Double stub table', {
    my $d = double('AllowRepo');
    allow($d).to.receive('find').and-return('via-allow');

    expect($d.find(1)).to.be('via-allow');
    expect($d.received('find')).to.be-truthy;
  }

  it 'restores the previous stub on cleanup', {
    my $d = double('AllowRepo', find => 'preset');
    allow($d).to.receive('find').and-return('overridden');
    expect($d.find(1)).to.be('overridden');
  }

  it '.and-call-original on a Double dies', {
    my $d = double('X');
    my $setup = allow($d).to.receive('foo');

    my $died = False;
    try {
      $setup.and-call-original;
      CATCH { default { $died = True } }
    }
    expect($died).to.be-truthy;
  }
}

describe 'before-all-installed stubs persist across examples', {
  before-all {
    allow(AllowRepo).to.receive('find').and-return('group-stub');
  }

  it 'first example sees the before-all stub', {
    expect(AllowRepo.find(1)).to.be('group-stub');
  }

  it 'second example also sees the before-all stub', {
    expect(AllowRepo.find(2)).to.be('group-stub');
  }
}
