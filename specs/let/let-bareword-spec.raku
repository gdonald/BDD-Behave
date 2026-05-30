use BDD::Behave;
use MONKEY-SEE-NO-EVAL;

sub compile-stderr(Str $code) {
  my $h = class :: {
    has $.sink is rw = '';
    method print(*@a) { $!sink ~= @a.join }
    method flush {}
  }.new;
  { my $*ERR = $h; try EVAL $code; }
  $h.sink;
}

describe 'bareword let', {
  context 'resolves in nested examples', {
    let(:owner, { 'ALICE' });

    it 'resolves as a plain term', {
      expect(owner).to.eq('ALICE');
    }

    it 'resolves in a method-call position', {
      expect(owner.chars).to.eq(5);
    }
  }

  context 'hyphenated names', {
    let(:u-seed, { 'BOB' });

    it 'resolves', {
      expect(u-seed).to.eq('BOB');
    }
  }

  context 'shadowing', {
    let(:x, { 'outer' });

    context 'inner', {
      let(:x, { 'inner' });

      it 'inner wins', {
        expect(x).to.eq('inner');
      }
    }

    it 'outer keeps its value', {
      expect(x).to.eq('outer');
    }
  }

  context 'let-bang', {
    let-bang(:eager, { 7 });

    it 'resolves the eager value', {
      expect(eager).to.eq(7);
    }
  }

  context 'subject', {
    subject(:thing, { 99 });

    it 'resolves the named subject', {
      expect(thing).to.eq(99);
    }
  }

  context 'fetch form', {
    let(:answer, { 42 });

    it 'resolves a colonpair fetch', {
      expect(let(:answer)).to.eq(42);
    }

    it 'resolves a positional fetch', {
      expect(let('answer')).to.eq(42);
    }
  }

  context 'compile-time safety', {
    it 'forward reference does not compile', {
      expect({
        EVAL 'use BDD::Behave; describe "f", { it "e", { y }; let(:y, { 1 }); }';
      }).to.raise;
    }

    it 'undeclared bareword does not compile', {
      expect({
        EVAL 'use BDD::Behave; describe "u", { it "e", { nope } }';
      }).to.raise;
    }

    it 'sibling context cannot see the other bareword', {
      expect({
        EVAL 'use BDD::Behave; describe "s", { context "a", { let(:only-a, { 1 }); it "x", { True } }; context "b", { it "y", { only-a } } }';
      }).to.raise;
    }
  }

  context 'shadowing warning', {
    it 'warns when a let shadows an existing sub', {
      my $err = compile-stderr(
        'use BDD::Behave; describe "w", { sub helper { 1 }; let(:helper, { 2 }); it "x", { True } }'
      );
      expect($err.contains('shadows')).to.be-truthy;
    }

    it 'is silent for let-over-let', {
      my $err = compile-stderr(
        'use BDD::Behave; describe "w", { let(:x, { 1 }); context "i", { let(:x, { 2 }); it "y", { True } } }'
      );
      expect($err.contains('shadows')).to.be-falsy;
    }
  }
}
