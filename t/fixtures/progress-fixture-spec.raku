use BDD::Behave;

describe 'progress-fixture', :order<defined>, {
  it 'first example passes', {
    expect(1 + 1).to.be(2);
  }

  it 'second example fails', {
    expect('a').to.be('b');
  }

  pending 'third example is pending', {
    expect(True).to.be(False);
  }

  xit 'fourth example is skipped', {
    expect(1).to.be(2);
  }

  it 'fifth example passes', {
    expect('hi'.uc).to.be('HI');
  }
}
