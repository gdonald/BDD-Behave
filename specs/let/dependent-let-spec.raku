use BDD::Behave;

describe 'a let that depends on another let in the same group', {
  let(:base,    { 10 });
  let(:derived, { $*LET-RUNTIME.value('base') * 2 });

  it 'sees the base value', {
    expect(:base).to.be(10);
  }

  it 'computes the derived value via $*LET-RUNTIME', {
    expect(:derived).to.be(20);
  }

  it 'returns the same memoized value across reads', {
    expect(:derived).to.be(20);
    expect(:derived).to.be(20);
  }
}

describe 'a let chain spanning nested groups', {
  let(:base, { 10 });

  context 'inside an inner context that adds a derived let', {
    let(:doubled, { $*LET-RUNTIME.value('base') * 2 });

    it 'walks ancestor lets to resolve dependencies', {
      expect(:doubled).to.be(20);
    }

    context 'and one more level adds a triple-derived let', {
      let(:bumped, { $*LET-RUNTIME.value('doubled') + 1 });

      it 'composes through more than one let dependency', {
        expect(:bumped).to.be(21);
      }
    }
  }
}

describe 'binding-style access returns the resolved value', {
  let(:answer, { 42 });

  it 'lets the binding capture the let value at read time', {
    my $a := let(:answer, { 42 });
    expect($a).to.be(42);
  }
}

describe 'a redefined let in an inner scope wins for derivations', {
  let(:base, { 1 });
  let(:derived, { $*LET-RUNTIME.value('base') + 100 });

  context 'when an inner context shadows the base let', {
    let(:base, { 5 });

    it 'derives from the nearest let, not the outermost', {
      expect(:derived).to.be(105);
    }
  }
}
