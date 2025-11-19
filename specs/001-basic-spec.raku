use BDD::Behave;

describe 'this spec', {
  it 'passes', {
    expect(42).to.be(42);
  }
}

describe 'this final spec', {
  it 'fails on the next line', {
    expect(42).to.be(41);
  }
}
