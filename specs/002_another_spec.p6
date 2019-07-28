
use Behave;

describe -> "this spec" {
  it -> "fails at line 6" {
    expect(42).to.be(41);
  }
}
