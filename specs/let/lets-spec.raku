use BDD::Behave;
use BDD::Behave::LetRuntime;

describe 'LetRuntime has-name', {
  let(:runtime, {
    LetRuntime.new(:definitions([LetDefinition.new(:name<foo>, :block({ 1 }))]));
  });

  it 'finds a defined let by name', {
    expect(runtime.has-name('foo')).to.be-truthy;
  }

  it 'ignores a leading colon on the query', {
    expect(runtime.has-name(':foo')).to.be-truthy;
  }

  it 'returns False for an undefined name', {
    expect(runtime.has-name('bar')).to.be-falsy;
  }
}

describe 'foo bar', {
  let(:number, { 42 });

  context 'bar baz', {
    it 'baz foo', {
      expect(42).to.be(42);
      expect(:number).to.be(42);
      expect(42).to.be(:number);
    }

    it 'can also use binding syntax', {
      my $num := let(:number, { 42 });
      expect($num).to.be(42);
    }
  }

  context 'baz foo', {
    let(:number, { '42' });

    it 'final foo bar has 3 expects', {
      expect('42').to.be('42');
      expect(:number).to.be('42');
      expect('42').to.be(:number);
    }
  }
}
