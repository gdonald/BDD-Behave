use BDD::Behave;

shared-context 'with widgets', {
  let(:widget, { 'gadget' });
  let(:count,  { 3 });
};

shared-context 'with logging', {
  my @log;
  before-each { @log = [] }
  let(:log, { @log });
};

shared-context 'with default name', {
  let(:name, { 'default' });
};

shared-context 'with prefix', -> $prefix {
  let(:greeting, { "$prefix, world" });
};

describe 'shared-context inclusion', {
  include-context 'with widgets';

  it 'pulls in lets from the shared context', {
    expect(:widget).to.be('gadget');
    expect(:count).to.be(3);
  }
}

describe 'shared-context with hooks', {
  include-context 'with logging';

  it 'starts with empty log per example', {
    expect($*LET-RUNTIME.value('log').elems).to.be(0);
  }

  it 'hook from shared context resets state across examples', {
    expect($*LET-RUNTIME.value('log').elems).to.be(0);
  }
}

describe 'inner let shadows shared-context let', {
  include-context 'with default name';
  let(:name, { 'override' });

  it 'sees the inner value', {
    expect(:name).to.be('override');
  }
}

describe 'parameterized shared context', {
  include-context 'with prefix', 'hello';

  it 'forwards arguments to the shared block', {
    expect(:greeting).to.be('hello, world');
  }
}

describe 'multiple shared contexts in one group', {
  include-context 'with widgets';
  include-context 'with default name';

  it 'merges lets from both shared contexts', {
    expect(:widget).to.be('gadget');
    expect(:name).to.be('default');
  }
}

describe 'nested groups inherit shared-context contributions', {
  include-context 'with widgets';

  context 'inner context', {
    include-context 'with default name';

    it 'sees lets from outer and inner shared contexts', {
      expect(:widget).to.be('gadget');
      expect(:name).to.be('default');
    }
  }
}
