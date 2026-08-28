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

describe 'LetRuntime listing the names it holds', {
  let(:runtime, {
    LetRuntime.new(:definitions([
      LetDefinition.new(:name<beta>,  :block({ 1 })),
      LetDefinition.new(:name<alpha>, :block({ 2 })),
      LetDefinition.new(:name<beta>,  :block({ 3 })),
    ]));
  });

  it 'names each definition once', {
    expect(runtime.names.elems).to.eq(2);
  }

  it 'keeps the order they were declared in', {
    expect(runtime.names.join(',')).to.eq('beta,alpha');
  }
}

describe 'LetRuntime resolving a name to a definition', {
  context 'given a name declared with a leading colon', {
    let(:runtime, {
      LetRuntime.new(:definitions([LetDefinition.new(:name(':colonised'), :block({ 'yes' }))]));
    });

    it 'finds it by its bare spelling', {
      expect(runtime.has-name('colonised')).to.be-truthy;
    }

    it 'reads its value by its bare spelling', {
      expect(runtime.value('colonised')).to.eq('yes');
    }

    it 'reads its value by its colon spelling', {
      expect(runtime.value(':colonised')).to.eq('yes');
    }
  }

  context 'given a name defined twice', {
    let(:runtime, {
      LetRuntime.new(:definitions([
        LetDefinition.new(:name<shadowed>, :block({ 'outer' })),
        LetDefinition.new(:name<shadowed>, :block({ 'inner' })),
      ]));
    });

    it 'reads the value of the last definition', {
      expect(runtime.value('shadowed')).to.eq('inner');
    }
  }

  context 'given a name defined twice in different spellings', {
    let(:runtime, {
      LetRuntime.new(:definitions([
        LetDefinition.new(:name<mixed>, :block({ 'outer' })),
        LetDefinition.new(:name(':mixed'), :block({ 'inner' })),
      ]));
    });

    it 'treats the two spellings as one name', {
      expect(runtime.value('mixed')).to.eq('inner');
    }
  }

  context 'given a definition added after the runtime was built', {
    let(:runtime, { LetRuntime.new(:definitions([])) });

    before-each {
      runtime().add-definition(LetDefinition.new(:name<added>, :block({ 'late' })));
    }

    it 'finds the added name', {
      expect(runtime.has-name('added')).to.be-truthy;
    }

    it 'reads the added value', {
      expect(runtime.value('added')).to.eq('late');
    }
  }

  context 'given a name that was never defined', {
    let(:runtime, { LetRuntime.new(:definitions([])) });

    it 'dies when the value is read', {
      expect({ runtime.value('missing') }).to.throw;
    }
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
