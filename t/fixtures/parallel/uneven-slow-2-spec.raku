use BDD::Behave;

describe 'uneven slow 2', {
  it 's2-a', { sleep 0.4; expect(1).to.be(1); }
  it 's2-b', { sleep 0.4; expect(1).to.be(1); }
  it 's2-c', { sleep 0.4; expect(1).to.be(1); }
}
