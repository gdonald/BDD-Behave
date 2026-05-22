use BDD::Behave;

# Intentional syntax error to make the parent fail to load this file.
this-sub-does-not-exist-and-cannot-be-called();

describe 'unreachable', {
  it 'never runs', { expect(1).to.be(1) }
}
