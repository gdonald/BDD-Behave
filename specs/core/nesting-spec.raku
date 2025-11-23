use BDD::Behave;

describe 'this spec has a let variable', {
  context 'with numeric value', {
    let(:foo, { 42 });

    it 'is successful', {
      expect(:foo).to.be(42);
    }

    it 'can use binding syntax', {
      my $foo := let(:foo, { 42 });
      expect($foo).to.be(42);
    }
  }

  context 'with string value', {
    let(:foo, { 'hello' });

    it 'uses string value from this context', {
      expect(:foo).to.be('hello');
    }

    it 'binding syntax works with strings too', {
      my $foo := let(:foo, { 'hello' });
      expect($foo).to.be('hello');
    }
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
  it 'passes', {
    expect(42).to.be(42);
  }
}
