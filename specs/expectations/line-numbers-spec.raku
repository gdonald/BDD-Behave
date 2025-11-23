use BDD::Behave;

let(:foo, { 42 });

describe 'this spec', {
  it 'passes', {
    expect(:foo).to.be(42);
  }

  it 'overrides let inside it block', {
    my $foo := let(:foo, { 41 });

    expect($foo).to.be(41);
  }
}

describe 'another spec', {
  let(:foo, { 17 });

  it 'passes', {
    expect(:foo).to.be(17);
  }

  it 'overrides let in this spec too', {
    my $foo := let(:foo, { 13 });
    expect($foo).to.be(13);
  }
}
