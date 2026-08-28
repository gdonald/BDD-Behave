use BDD::Behave;

describe 'declaring a group the wrong way', {
  it 'refuses a describe with no block', {
    expect({ describe('a description only') })
      .to.raise-error(/'expects a description string and a block'/);
  }

  it 'refuses a context with no block', {
    expect({ context('a description only') })
      .to.raise-error(/'expects a description string and a block'/);
  }
}

describe 'reading a let through a binding', {
  let(:balance, { 100 });

  it 'reads the value by bareword', {
    expect(balance()).to.be(100);
  }

  it 'reads the value through a bound name', {
    my $bound := let(:balance, { 100 });

    expect($bound).to.be(100);
  }
}

describe 'a named eager subject declared by a string', {
  subject-bang('ledger', { 'built eagerly' });

  it 'is read back by that name', {
    expect(:ledger).to.eq('built eagerly');
  }
}

describe 'is-expected without a subject', {
  it 'says a subject is needed', {
    expect({ is-expected.to.be(1) })
      .to.raise-error(/'requires a subject'/);
  }
}

describe 'is-expected with a subject', {
  subject { 42 }

  it 'compares against the subject', {
    is-expected.to.be(42);
  }
}

describe 'comparing against a let by name', {
  let(:answer, { 42 });

  it 'reads the let named on the left', {
    expect(:answer).to.be(42);
  }

  it 'reads the let named on the right', {
    expect(42).to.be(:answer);
  }

  it 'refuses a name no let declared', {
    expect({ expect(:no-such-let).to.be(1) }).to.raise-error(/'Unknown let'/);
  }
}
