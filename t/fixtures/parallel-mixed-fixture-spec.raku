use BDD::Behave;

describe 'parallel-mixed-fixture', :order<defined>, {
  it 'p1', { expect(1).to.be(1) }
  it 'p2', { expect(2).to.be(2) }
  it 'p3', { expect(3).to.be(3) }
  it 'p4', { expect(4).to.be(4) }
  it 'fail-1', { expect(1).to.be(2) }
  pending 'pending-1';
  xit 'skip-1', { expect(0).to.be(0) }
  it 'p5', { expect(5).to.be(5) }
  it 'fail-2', { expect('a').to.be('b') }
}
