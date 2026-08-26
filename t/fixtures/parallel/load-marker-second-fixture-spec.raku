use BDD::Behave;

with %*ENV<BEHAVE_LOAD_MARKER> { .IO.spurt("loaded\n", :append) }

describe 'second load marker fixture', {
  it 'passes', { expect(1).to.be(1) }
}
