
use Behave;

describe -> 'this spec' {
  it -> 'passes' {
    expect(42).to.be(42);
  }
}

describe -> 'this spec' {
  it -> 'fails at line 12' {
    expect(42).to.be(41);
  }
}
