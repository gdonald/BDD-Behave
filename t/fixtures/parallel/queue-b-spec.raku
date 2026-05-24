use BDD::Behave;

describe 'queue fixture B', {
  it 'b1', { expect('x').to.be('x'); }
  it 'b2', { expect([1, 2, 3].sum).to.be(6); }
  it 'b3 fails', { expect(1).to.be(2); }
}
