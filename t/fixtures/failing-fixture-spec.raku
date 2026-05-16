use BDD::Behave;

describe 'failing-fixture', :order<defined>, {
  it 'first example fails', {
    expect(1).to.be(2);
  }

  it 'second example fails', {
    expect('a').to.be('b');
  }

  it 'third example fails', {
    expect(True).to.be(False);
  }

  it 'fourth example passes', {
    expect(1).to.be(1);
  }
}
