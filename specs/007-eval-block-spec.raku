
use BDD::Behave;

# DATA-BEGIN
my $foo = 'bar';
# DATA-END

describe -> 'this spec' {
  it -> 'passes' {
    expect($foo).to.be('bar');
  }
}
