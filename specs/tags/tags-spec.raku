use BDD::Behave;

describe 'tagging examples', {
  it 'accepts a single :tag', :tag<fast>, {
    expect(1 + 1).to.be(2);
  }

  it 'accepts :tags with multiple names', :tags<critical performance>, {
    expect('hi'.uc).to.be('HI');
  }

  it 'still runs without any tag', {
    expect(True).to.be-truthy;
  }
}

describe 'tagging on describe propagates', :tag<integration>, {
  it 'inherits its parent group tag', {
    expect(42).to.be(42);
  }

  context 'with another tag layer', :tag<network>, {
    it 'inherits both ancestor tags', :tag<flaky>, {
      expect('a'.chars).to.be(1);
    }
  }
}

describe 'untagged describe', {
  it 'has no tags by default', {
    expect(['a', 'b'].elems).to.be(2);
  }
}
