use BDD::Behave;

# Sleeps at load time so a discovery subprocess stays alive long enough for the
# parent's discovery timeout to fire.
sleep 30;

describe 'never discovered', {
  it 'is unreachable', {
    expect(1).to.be(1);
  }
}
