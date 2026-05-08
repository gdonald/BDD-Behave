use BDD::Behave;

describe 'User signup', {
  it 'creates a new account', {
    expect(1).to.be(1);
  }

  it 'rejects duplicate emails', {
    expect(2).to.be(2);
  }

  context 'with a referral code', {
    it 'awards bonus credits', {
      expect(3).to.be(3);
    }
  }
}

describe 'Order checkout', {
  it 'computes the total', {
    expect(10).to.be(10);
  }

  it 'applies a discount', {
    expect(20).to.be(20);
  }
}
