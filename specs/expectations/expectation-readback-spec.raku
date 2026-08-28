use BDD::Behave;
use BDD::Behave::Failures;

my class Ledger {
  has Int $.balance is rw = 0;
}

# An expectation reports whether it passed, so a spec can branch on one without
# reading the failure list. The failure list is reset around each of these so a
# deliberate miss does not fail the example that made it.
sub outcome-of(&expectation --> Bool) {
  Failures.list = ();
  my $passed = ?expectation();
  Failures.list = ();

  $passed;
}

describe 'reading back whether a change expectation passed', {
  it 'reports a change that happened', {
    my $ledger = Ledger.new;

    expect(outcome-of({
      expect({ $ledger.balance = 5 }).to.change({ $ledger.balance });
    })).to.be-truthy;
  }

  it 'reports a change that did not happen', {
    my $ledger = Ledger.new;

    expect(outcome-of({
      expect({ 'nothing here' }).to.change({ $ledger.balance });
    })).to.be-falsy;
  }

  it 'reports a change of the size that was asked for', {
    my $ledger = Ledger.new;

    expect(outcome-of({
      expect({ $ledger.balance += 3 }).to.change({ $ledger.balance }).by(3);
    })).to.be-truthy;
  }
}

describe 'reading back whether an error expectation passed', {
  it 'reports a block that raised', {
    expect(outcome-of({ expect({ die 'boom' }).to.raise-error })).to.be-truthy;
  }

  it 'reports a block that stayed quiet', {
    expect(outcome-of({ expect({ 'quiet' }).to.raise-error })).to.be-falsy;
  }

  it 'reports a message that matched', {
    expect(outcome-of({ expect({ die 'boom' }).to.raise-error(/'oo'/) })).to.be-truthy;
  }
}

describe 'an eventually chain written with a second to', {
  it 'reads the same as one written without it', {
    expect({ 'ready' }).to.eventually.to.be('ready');
  }

  it 'still takes a timeout', {
    expect({ 'ready' }).to.eventually(:timeout(1)).to.be('ready');
  }
}

describe 'comparing against a let that was never declared', {
  let(:known, { 42 });

  it 'reads a let that exists', {
    expect(42).to.be(:known);
  }

  it 'refuses a name no let declared', {
    expect({ expect(42).to.be(:no-such-let) }).to.raise-error(/'Unknown let'/);
  }

  it 'names the let it could not find', {
    expect({ expect(42).to.be(:no-such-let) }).to.raise-error(/'no-such-let'/);
  }
}
