use BDD::Behave;

describe 'fit { ... } block-only focuses one-liner examples', {
  it 'unfocused', { expect(1).to.be(1) }
  fit { expect(2).to.be(2) }
}

describe 'xit { ... } block-only skips one-liner examples', {
  it 'this still runs', { expect(1).to.be(1) }
  xit { expect(2).to.be(99) }
}
