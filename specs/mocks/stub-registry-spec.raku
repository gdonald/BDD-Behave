use BDD::Behave;
use BDD::Behave::Mock::Stub;

my class Ledger {
  method balance { 100 }
  method deposit($amount) { $amount }
}

describe 'the registry of installed stubs', {
  let(:ledger, { Ledger.new });

  # Each example installs its own stubs and takes them off again, so the count
  # a spec sees never depends on what ran before it.
  let(:snapshot, { StubRegistry.active-count });

  # The count is taken before any stub is installed, so a later comparison is
  # against the state this example started from.
  before-each { snapshot() }

  after-each { StubRegistry.clear-since(snapshot()) }

  it 'reports an object with a stub installed', {
    allow(ledger()).to.receive('balance').and-return(1);

    expect(StubRegistry.any-for(ledger())).to.be-truthy;
  }

  it 'does not report an object with no stub installed', {
    allow(ledger()).to.receive('balance').and-return(1);

    expect(StubRegistry.any-for(Ledger.new)).to.be-falsy;
  }

  it 'finds a stub by its object and method', {
    allow(ledger()).to.receive('balance').and-return(1);

    expect(StubRegistry.find-existing(ledger(), 'balance').method-name).to.eq('balance');
  }

  it 'finds no stub for a method that was never stubbed', {
    allow(ledger()).to.receive('balance').and-return(1);

    expect(StubRegistry.find-existing(ledger(), 'deposit')).to.be(Nil);
  }

  it 'counts the stubs it holds', {
    allow(ledger()).to.receive('balance').and-return(1);

    expect(StubRegistry.active-count).to.be(snapshot() + 1);
  }

  context 'given a stub taken off by hand', {
    before-each {
      allow(ledger()).to.receive('balance').and-return(1);
      StubRegistry.remove(StubRegistry.find-existing(ledger(), 'balance'));
    }

    it 'no longer holds it', {
      expect(StubRegistry.active-count).to.be(snapshot());
    }

    it 'lets the real method answer again', {
      expect(ledger().balance).to.be(100);
    }
  }

  context 'given a stub that was already taken off', {
    it 'ignores a second removal', {
      allow(ledger()).to.receive('balance').and-return(1);
      my $stub = StubRegistry.find-existing(ledger(), 'balance');
      StubRegistry.remove($stub);
      StubRegistry.remove($stub);

      expect(StubRegistry.active-count).to.be(snapshot());
    }
  }
}

describe 'the calls a stub records', {
  let(:ledger, { Ledger.new });
  let(:snapshot, { StubRegistry.active-count });
  let(:stub, {
    allow(ledger()).to.receive('deposit').and-return('stubbed');
    StubRegistry.find-existing(ledger(), 'deposit');
  });

  after-each { StubRegistry.clear-since(snapshot()) }

  before-each {
    stub();
    ledger().deposit(10);
    ledger().deposit(20);
  }

  it 'keeps one record per call', {
    expect(stub().calls.elems).to.be(2);
  }

  it 'counts the calls to the method', {
    expect(stub().call-count('deposit')).to.be(2);
  }

  it 'reports having received the method', {
    expect(stub().received('deposit')).to.be-truthy;
  }

  it 'reports not having received another method', {
    expect(stub().received('balance')).to.be-falsy;
  }

  it 'keeps the arguments of a call', {
    expect(stub().calls[1].args[0]).to.be(20);
  }
}

describe 'what a stub answers with', {
  let(:ledger, { Ledger.new });
  let(:snapshot, { StubRegistry.active-count });

  before-each { snapshot() }

  after-each { StubRegistry.clear-since(snapshot()) }

  it 'answers with the value it was given', {
    allow(ledger()).to.receive('balance').and-return(7);

    expect(ledger().balance).to.be(7);
  }

  it 'raises the exception it was given', {
    allow(ledger()).to.receive('balance').and-raise(X::AdHoc.new(:payload('no balance')));

    expect({ ledger().balance }).to.raise-error(/'no balance'/);
  }

  it 'leaves another instance of the same class alone', {
    allow(ledger()).to.receive('balance').and-return(7);

    expect(Ledger.new.balance).to.be(100);
  }

  it 'refuses to stub a method the class does not have', {
    expect({ allow(ledger()).to.receive('missing').and-return(1) })
      .to.raise-error(/"has no method 'missing'"/);
  }
}

describe 'a stub installed on a double', {
  let(:snapshot, { StubRegistry.active-count });

  before-each { snapshot() }

  after-each { StubRegistry.clear-since(snapshot()) }

  it 'answers with the value it was given', {
    my $log = double('Logger');
    allow($log).to.receive('level').and-return('warn');

    expect($log.level).to.eq('warn');
  }

  it 'raises the exception it was given', {
    my $log = double('Logger');
    allow($log).to.receive('level').and-raise(X::AdHoc.new(:payload('no level')));

    expect({ $log.level }).to.raise-error(/'no level'/);
  }

  it 'answers from the block it was given', {
    my $log = double('Logger');
    allow($log).to.receive('level').and-do(-> { 'from a block' });

    expect($log.level).to.eq('from a block');
  }

  it 'refuses to call an original that does not exist', {
    my $log = double('Logger');

    expect({ allow($log).to.receive('level').and-call-original })
      .to.raise-error(/'no original method'/);
  }
}

describe 'clearing every stub the registry holds', {
  let(:ledger, { Ledger.new });

  it 'leaves the registry empty', {
    allow(ledger()).to.receive('balance').and-return(1);
    StubRegistry.clear-all;

    expect(StubRegistry.active-count).to.be(0);
  }

  it 'lets the real method answer again', {
    allow(ledger()).to.receive('balance').and-return(1);
    StubRegistry.clear-all;

    expect(ledger().balance).to.be(100);
  }
}
