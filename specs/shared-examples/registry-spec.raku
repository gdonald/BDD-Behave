use BDD::Behave;
use BDD::Behave::SharedExamples;

constant SharedExampleRegistry = BDD::Behave::SharedExamples::SharedExampleRegistry;

my &counter-body = -> { 'counter' };

describe 'the shared examples registry', {
  let(:store, { SharedExampleRegistry.new });

  context 'given a registered name', {
    before-each {
      store().register('a counter', &counter-body);
    }

    it 'reports the name as registered', {
      expect(store().exists('a counter')).to.be-truthy;
    }

    it 'looks the block up by name', {
      expect(store().lookup('a counter')).to.be(&counter-body);
    }

    it 'lists the name', {
      expect(store().names.list).to.eq(('a counter',));
    }
  }

  it 'hands back the block it was given to register', {
    expect(store().register('a counter', &counter-body)).to.be(&counter-body);
  }

  context 'given several registered names', {
    before-each {
      store().register($_, &counter-body) for <charlie alpha bravo>;
    }

    it 'lists them in sorted order', {
      expect(store().names.list).to.eq(('alpha', 'bravo', 'charlie'));
    }

    it 'forgets all of them when cleared', {
      store().clear;

      expect(store().names.elems).to.be(0);
    }
  }

  context 'given a name that was registered twice', {
    before-each {
      store().register('shadowed', -> { 'first' });
      store().register('shadowed', -> { 'second' });
    }

    it 'looks up the block registered last', {
      expect(store().lookup('shadowed').()).to.eq('second');
    }
  }

  context 'given a name that was never registered', {
    it 'does not report it as registered', {
      expect(store().exists('missing')).to.be-falsy;
    }

    it 'names it in the error raised by a lookup', {
      expect({ store().lookup('missing') })
        .to.raise-error(/"Unknown shared examples: 'missing'"/);
    }
  }

  context 'given nothing registered at all', {
    it 'lists no names', {
      expect(store().names.elems).to.be(0);
    }
  }
}

describe 'the shared examples registry every spec file shares', {
  it 'hands back one registry', {
    expect(registry()).to.be(registry());
  }

  it 'hands back a shared examples registry', {
    expect(registry() ~~ SharedExampleRegistry).to.be-truthy;
  }
}
