use BDD::Behave;
use BDD::Behave::SharedContexts;

constant SharedContextRegistry = BDD::Behave::SharedContexts::SharedContextRegistry;

my &database-body = -> { 'database' };

describe 'the shared context registry', {
  let(:store, { SharedContextRegistry.new });

  context 'given a registered name', {
    before-each {
      store().register('a database', &database-body);
    }

    it 'reports the name as registered', {
      expect(store().exists('a database')).to.be-truthy;
    }

    it 'looks the block up by name', {
      expect(store().lookup('a database')).to.be(&database-body);
    }

    it 'lists the name', {
      expect(store().names.list).to.eq(('a database',));
    }
  }

  it 'hands back the block it was given to register', {
    expect(store().register('a database', &database-body)).to.be(&database-body);
  }

  context 'given several registered names', {
    before-each {
      store().register($_, &database-body) for <charlie alpha bravo>;
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
        .to.raise-error(/"Unknown shared context: 'missing'"/);
    }
  }

  context 'given nothing registered at all', {
    it 'lists no names', {
      expect(store().names.elems).to.be(0);
    }
  }
}

describe 'the shared context registry every spec file shares', {
  it 'hands back one registry', {
    expect(registry()).to.be(registry());
  }

  it 'hands back a shared context registry', {
    expect(registry() ~~ SharedContextRegistry).to.be-truthy;
  }
}
