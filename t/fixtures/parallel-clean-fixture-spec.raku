use BDD::Behave;

describe 'parallel-clean-fixture', :order<defined>, {
  it 'p1', { expect(1).to.be(1) }
  it 'p2', { expect(2).to.be(2) }
}
