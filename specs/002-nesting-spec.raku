
use BDD::Behave;

describe 'this spec has a given variable', {
  let(:foo, { 42 });

  it 'is successful', {
    expect(:foo).to.be(42);
  }
}

describe 'this spec', {
  it 'is successful', {
    expect(42).to.be(42);
  }
}

describe 'this other not spec', {
  it 'is a success', {
    expect(42).to.not.be(41);
  }
}

describe 'this spec has contexts', {
  context 'with an it block', {
    it 'is successful', {
      expect(42).to.be(42);
    }
  }

  context 'with more than one it block', {
    it 'is successful', {
      expect(42).to.be(42);
    }

    it 'is good to go', {
      expect(42).to.not.be(41);
    }
  }
}

describe 'this describe has a describe', {
  describe 'this describe has two contexts', {
    context 'one has a single it block', {
      it 'is successful', {
        expect(42).to.be(42);
      }
    }

    context 'the other has two it blocks', {
      it 'is successful', {
        expect(42).to.be(42);
      }

      it 'is also successful', {
        expect(42).to.not.be(41);
      }
    }
  }
}

describe 'this spec has an expected variable', {
  let(:foo, { 42 });

  it 'is successful', {
    expect(42).to.be(:foo);
  }
}

describe 'this spec has a to and a not', {
  it 'is successful', {
    expect(42).to.be(42);
  }

  it 'is also successful', {
    expect(42).to.not.be(41);
  }
}

describe 'this final spec', {
  it 'fails at line 82', {
    expect(42).to.be(41);
  }
}
