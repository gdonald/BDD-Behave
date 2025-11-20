use BDD::Behave;

let(:top, { 'top-level' });

describe 'let scoping', {
  it 'can access top-level let', {
    expect(:top).to.be('top-level');
  }

  describe 'describe-level let', {
    let(:desc, { 'describe-level' });

    it 'can access describe-level let', {
      expect(:desc).to.be('describe-level');
    }

    it 'can access top-level let from nested describe', {
      expect(:top).to.be('top-level');
    }

    context 'context-level let', {
      let(:ctx, { 'context-level' });

      it 'can access context-level let', {
        expect(:ctx).to.be('context-level');
      }

      it 'can access describe-level let from context', {
        expect(:desc).to.be('describe-level');
      }

      it 'can access top-level let from context', {
        expect(:top).to.be('top-level');
      }
    }
  }

  describe 'let override in describe', {
    let(:value, { 'outer' });

    it 'uses outer value by default', {
      expect(:value).to.be('outer');
    }

    context 'nested context with override', {
      let(:value, { 'inner' });

      it 'uses inner value in nested context', {
        expect(:value).to.be('inner');
      }
    }

    it 'still uses outer value after nested context', {
      expect(:value).to.be('outer');
    }
  }

  describe 'let inside it block', {
    let(:outer, { 'from-describe' });

    it 'can override let inside it block', {
      let(:outer, { 'from-it' });
      expect(:outer).to.be('from-it');
    }

    it 'outer let is unaffected by override in other it block', {
      expect(:outer).to.be('from-describe');
    }

    it 'can declare new let inside it block', {
      let(:it-only, { 'only-in-it' });
      expect((:it-only)).to.be('only-in-it');
    }
  }
}

describe 'another describe block', {
  let(:top, { 'override-top' });

  it 'can override top-level let in describe', {
    expect(:top).to.be('override-top');
  }
}

describe 'back to using top-level', {
  it 'top-level let is restored after override in other describe', {
    expect(:top).to.be('top-level');
  }
}
