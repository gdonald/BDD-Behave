
use BDD::Behave;

describe -> 'this spec' {
  it -> 'passes' {
    expect(42).to.be(42);
  }
}

describe -> 'this other spec' {
  it -> 'fails at line 12' {
    expect(42).to.be(41);
  }
}
