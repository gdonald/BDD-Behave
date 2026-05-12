use BDD::Behave;

this-symbol-does-not-exist;

describe 'never runs', {
  it 'is unreachable', {
    expect(1).to.be(1);
  }
}
