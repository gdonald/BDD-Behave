use BDD::Behave;

describe 'profile-fixture', :order<defined>, {
  it 'a fast example', {
    expect(1).to.be(1);
  }

  it 'b medium example', {
    sleep 0.05;
    expect(1).to.be(1);
  }

  it 'c slow example', {
    sleep 0.12;
    expect(1).to.be(1);
  }
}
