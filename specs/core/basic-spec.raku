use BDD::Behave;

describe 'this spec', {
  it 'passes', {
    expect(42).to.be(42);
  }
}

describe 'this final spec', {
  it 'also passes', {
    expect(42).to.be(42);
  }
}
