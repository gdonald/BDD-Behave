use BDD::Behave;

describe 'a spec file that calls a routine it never imports', {
  it 'does not load', {
    expect(Member('owner')).to.be-truthy;
  }
}
