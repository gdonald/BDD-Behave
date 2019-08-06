
use Behave;

my $foo = 42;

describe -> 'this spec' {
  it -> 'passes' {
    expect($foo).to.be(42);
  }

  it -> 'fails' {
    $foo = 41;
    expect($foo).to.be(42);
  }
}

describe -> 'another spec' {
  $foo = 17;

  it -> 'passes' {
    expect($foo).to.be(17);
  }

  it -> 'fails' {
    $foo = 13;
    expect($foo).to.be(17);
  }
}

