
use BDD::Behave;

#describe 'this is commented out', {
#  let(:number) => { 42 };
#
#  context 'has one it', {
#    it 'has one expect', {
#      expect(42).to.be(42);
#    }
#  }
#}

describe 'foo bar', {
  let(:number) => { 42 };

  context 'bar baz', {
    it 'has two expects', {
      expect(42).to.be(42);
      expect(:number).to.be(42);
      # expect(42).to.be(:number);
    }
  }

  context 'baz foo', {
    let(:number) => { '42' };

    it 'has one expect', {
      expect('42').to.be('42');
#      expect(:number).to.be('42');
#      expect('42').to.be(:number);
    }
  }
}

describe 'foo bar', {
  let(:number) => { 42 };

  context 'has one it', {
#    it 'has two expects', {
#      expect(42).to.be(42);
#      expect(:number).to.be(42);
#    }

    it -> 'has two expects' {
      expect(42).to.be(42);
      expect(:number).to.be(42);
    }

    # it -> 'has two expects' {
    #  expect(42).to.be(42);
      #expect(:number).to.be(42);
  #  }
  }
}

describe -> 'has one context' {
  let(:number) => { 42 };

  context -> 'has one it' {
    it -> 'has one expect' {
      expect(42).to.be(42);
    }
  }

#  context -> 'has one it' {
#    it -> 'has two expects' {
#      expect(42).to.be(42);
#    }
#  }
}

describe -> 'has one describe' {
  let(:number) => { 42 };

  describe -> 'has one context' {
    let(:number) => { 42 };

    context -> 'has one it' {
      it -> 'has one expect' {
        expect(42).to.be(42);
      }
    }

    #  context -> 'has one it' {
    #    it -> 'has two expects' {
    #      expect(42).to.be(42);
    #    }
    #  }
  }

  describe -> 'has two contexts' {
    let(:number) => { 42 };

    context -> 'has one it' {
      it -> 'has one expect' {
        expect(42).to.be(42);
      }
    }

    #  context -> 'has one it' {
    #    it -> 'has two expects' {
    #      expect(42).to.be(42);
    #    }
    #  }

    context -> 'has a single it' {
      it -> 'with one expect' {
        expect(42).to.be(42);
      }
    }
  }
}

#describe -> 'this is commented out' {
#  let(:number) => { 42 };
#
#  context -> 'has one it' {
#    it -> 'has one expect' {
#      expect(42).to.be(42);
#    }
#  }
#}

describe -> 'has comments on the right of the code' { # comment
  let(:number) => { 42 }; # comment

  context -> 'has one it' { # comment
    it -> 'has one expect' { # comment
      expect(42).to.be(42); # comment
    } # comment
  } # comment

  describe -> 'has more comments on the right' {# comment
    let(:number) => { 42 }; #comment
#
    context -> 'has one it' {# comment
      it -> 'has one expect' {# comment
        expect(42).to.be(42);# comment
        expect(42).to.not.be(41);# comment
      }# comment
    }# comment
  }# comment

} # comment

describe -> 'has more comments on the right' {# comment
  let(:number) => { 42 }; #comment
  #
  context -> 'has one it' {# comment
    it -> 'has two final expects' {# comment
      expect(42).to.be(42);# comment
      expect(42).to.not.be(41);# comment
    }# comment
  }# comment
}# comment
