use BDD::Behave;

describe 'queue fixture C', {
  it 'c1', :serial, { expect(True).to.be-truthy; }
  it 'c2', { expect((1..4).sum).to.be(10); }
}
