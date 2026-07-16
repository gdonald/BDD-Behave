use BDD::Behave;

# Records each process that loads this file, so tests can count how many
# subprocesses (precompile pass, discovery, worker) performed a load.
with %*ENV<BEHAVE_LOAD_MARKER> { .IO.spurt("loaded\n", :append) }

describe 'load marker fixture', {
  it 'passes', { expect(1).to.be(1) }
}
