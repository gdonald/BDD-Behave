use BDD::Behave;

# Six fast 3-example groups paired with the two slow fixtures so that
# every bucket has the same example count. Static LPT can't distinguish
# slow from fast by cost proxy and may pile both slow groups onto one
# worker; queue-mode work-stealing balances them dynamically.

describe 'uneven fast 1', {
  it 'f1-a', { expect(1).to.be(1); }
  it 'f1-b', { expect(1).to.be(1); }
  it 'f1-c', { expect(1).to.be(1); }
}

describe 'uneven fast 2', {
  it 'f2-a', { expect(1).to.be(1); }
  it 'f2-b', { expect(1).to.be(1); }
  it 'f2-c', { expect(1).to.be(1); }
}

describe 'uneven fast 3', {
  it 'f3-a', { expect(1).to.be(1); }
  it 'f3-b', { expect(1).to.be(1); }
  it 'f3-c', { expect(1).to.be(1); }
}

describe 'uneven fast 4', {
  it 'f4-a', { expect(1).to.be(1); }
  it 'f4-b', { expect(1).to.be(1); }
  it 'f4-c', { expect(1).to.be(1); }
}

describe 'uneven fast 5', {
  it 'f5-a', { expect(1).to.be(1); }
  it 'f5-b', { expect(1).to.be(1); }
  it 'f5-c', { expect(1).to.be(1); }
}

describe 'uneven fast 6', {
  it 'f6-a', { expect(1).to.be(1); }
  it 'f6-b', { expect(1).to.be(1); }
  it 'f6-c', { expect(1).to.be(1); }
}
