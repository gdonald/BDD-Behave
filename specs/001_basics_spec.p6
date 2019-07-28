
use Behave;

describe -> 'this spec' {
  it -> 'is succesful' {
    expect(42).to.be(42);
  }
}

describe -> 'this other spec' {
  it -> 'is a big failure' {
    expect(42).to.not.be(41);
  }
}

describe -> 'this spec has contexts' {
  context -> 'with an it block' {
    it -> 'is succesful' {
      expect(42).to.be(42);
    }
  }

  context -> 'with more than one it block' {
    it -> 'is succesful' {
      expect(42).to.be(42);
    }

    it -> 'is a big failure' {
      expect(42).to.not.be(41);
    }
  }
}

describe -> 'this describe has describes with contexts' {
  describe -> 'this describe has contexts' {
    context -> 'with an it block' {
      it -> 'is succesful' {
        expect(42).to.be(42);
      }
    }

    context -> 'with more than one it block' {
      it -> 'is succesful' {
        expect(42).to.be(42);
      }

      it -> 'is a big failure' {
        expect(42).to.not.be(41);
      }
    }
  }
}

describe -> 'this spec has a given variable' {
  my $foo = 42;

  it -> 'is succesful' {
    expect($foo).to.be(42);
  }
}

describe -> 'this spec has an expected variable' {
  my $foo = 42;

  it -> 'is succesful' {
    expect(42).to.be($foo);
  }
}

describe -> 'this spec have to and not' {
  it -> 'is succesful' {
    expect(42).to.be(42);
  }

  it -> 'is succesful' {
    expect(42).to.not.be(41);
  }
}

describe -> 'this spec' {
  it -> 'fails at line 82' {
    expect(42).to.be(41);
  }
}
