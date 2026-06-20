use BDD::Behave;

describe 'worker env at load', {
  it "count={ %*ENV<BEHAVE_WORKER_COUNT> // 'UNSET' }", { expect(True).to.be(True) }
  it "index={ %*ENV<BEHAVE_WORKER_INDEX> // 'UNSET' }", { expect(True).to.be(True) }
}
