use BDD::Behave;

my class PartialAccount {
  has Int $.balance is rw = 0;
  method deposit($n)  { $!balance += $n; $!balance }
  method withdraw($n) { $!balance -= $n; $!balance }
  method label        { "Account($!balance)" }
}

my class PartialRepo {
  method find($id)    { "real:$id"   }
  method save($obj)   { "saved:$obj" }
  method delete($id)  { "deleted:$id" }
}

describe 'partial mocking on instances', {
  it 'stubs only the targeted method; siblings on the same instance keep working', {
    my $a = PartialAccount.new(balance => 100);

    allow($a).to.receive('label').and-return('STUB-LABEL');

    expect($a.label).to.be('STUB-LABEL');
    expect($a.deposit(50)).to.be(150);
    expect($a.withdraw(25)).to.be(125);
    expect($a.balance).to.be(125);
  }

  it 'stubs multiple methods on the same instance independently', {
    my $r = PartialRepo.new;

    allow($r).to.receive('find').and-return('stub-find');
    allow($r).to.receive('save').and-return('stub-save');

    expect($r.find(1)).to.be('stub-find');
    expect($r.save('x')).to.be('stub-save');
    expect($r.delete(7)).to.be('deleted:7');
  }

  it 'leaves sibling instances of the same class unaffected', {
    my $a = PartialAccount.new(balance => 0);
    my $b = PartialAccount.new(balance => 200);

    allow($a).to.receive('label').and-return('STUB');

    expect($a.label).to.be('STUB');
    expect($b.label).to.be('Account(200)');
  }
}

describe 'auto-cleanup restores the original method between examples', {
  it 'first example installs an instance stub', {
    my $a = PartialAccount.new(balance => 10);
    allow($a).to.receive('deposit').and-return(999);
    expect($a.deposit(1)).to.be(999);
  }

  it 'second example sees the original implementation', {
    my $a = PartialAccount.new(balance => 10);
    expect($a.deposit(5)).to.be(15);
  }
}

describe 'allow-any-instance-of(Class)', {
  it 'stubs the same instance method across every instance of the class', {
    allow-any-instance-of(PartialRepo).to.receive('find').and-return('stub-any');

    expect(PartialRepo.new.find(1)).to.be('stub-any');
    expect(PartialRepo.new.find(2)).to.be('stub-any');
  }

  it 'is auto-cleaned between examples', {
    expect(PartialRepo.new.find(3)).to.be('real:3');
  }

  it 'a per-instance allow on the same method takes precedence for that instance', {
    my $repo = PartialRepo.new;

    allow-any-instance-of(PartialRepo).to.receive('find').and-return('class-wide');
    allow($repo).to.receive('find').and-return('instance-specific');

    expect($repo.find(1)).to.be('instance-specific');
    expect(PartialRepo.new.find(2)).to.be('class-wide');
  }

  it 'rejects an instance argument', {
    my $r = PartialRepo.new;
    my $died = False;
    try {
      allow-any-instance-of($r).to.receive('find');
      CATCH { default { $died = True } }
    }
    expect($died).to.be-truthy;
  }

  it 'rejects a method the class does not define', {
    my $died = False;
    try {
      allow-any-instance-of(PartialRepo).to.receive('imaginary');
      CATCH { default { $died = True } }
    }
    expect($died).to.be-truthy;
  }

  it 'supports .and-raise', {
    allow-any-instance-of(PartialRepo).to.receive('save')
      .and-raise(X::AdHoc.new(payload => 'nope'));

    my $msg = '';
    try {
      PartialRepo.new.save('x');
      CATCH { default { $msg = .message } }
    }
    expect($msg).to.be('nope');
  }

  it 'supports .and-do', {
    allow-any-instance-of(PartialRepo).to.receive('find')
      .and-do(-> $id { "computed:$id" });

    expect(PartialRepo.new.find(7)).to.be('computed:7');
  }
}

describe 'partial mocking with spy on a real instance', {
  it 'stubs one method, leaves the rest real, and records calls', {
    my $a = PartialAccount.new(balance => 50);

    spy($a);
    allow($a).to.receive('label').and-return('SPY');

    expect($a.label).to.be('SPY');
    expect($a.deposit(10)).to.be(60);

    expect($a).to.have-received('label');
    expect($a).to.have-received('deposit').with(10);
  }
}
