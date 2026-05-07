use BDD::Behave;

describe 'metadata-keyed before-each hooks', {
  my @log;

  before-each {
    @log = ();
  }

  before-each :tag<database>, {
    @log.push('db-setup');
  }

  it 'fires the filtered hook only when the tag matches', :tag<database>, {
    expect(@log.elems).to.be(1);
    expect(@log[0]).to.be('db-setup');
  }

  it 'skips the filtered hook for an untagged example', {
    expect(@log.elems).to.be(0);
  }

  it 'skips the filtered hook for examples with a different tag', :tag<api>, {
    expect(@log.elems).to.be(0);
  }
}

describe 'metadata-keyed after-each hooks', {
  my @log;

  after-each :tag<slow>, {
    @log.push('teardown-slow');
  }

  it 'records nothing yet on the first matching example', :tag<slow>, {
    expect(@log.elems).to.be(0);
  }

  it 'sees the after-each from the previous example', :tag<slow>, {
    expect(@log[*-1]).to.be('teardown-slow');
  }

  it 'untagged examples do not trigger the filtered after-each', {
    expect(@log.grep('teardown-slow').elems > 0 ?? 1 !! 0).to.be(1);
  }
}

describe 'AND semantics across multiple filter keys', {
  my @log;

  before-each {
    @log = ();
  }

  before-each :tag<database>, :exclude-tag<read-only>, {
    @log.push('write-db');
  }

  it 'matches when included tag present and excluded tag absent', :tag<database>, {
    expect(@log[0]).to.be('write-db');
  }

  it 'skips when an excluded tag is present', :tags<database read-only>, {
    expect(@log.elems).to.be(0);
  }
}

describe 'multiple include tags require ALL', {
  my @log;

  before-each {
    @log = ();
  }

  before-each :tags<database integration>, {
    @log.push('hit');
  }

  it 'fires when both required tags are present', :tags<database integration>, {
    expect(@log[0]).to.be('hit');
  }

  it 'skips when only one of the required tags is present', :tag<database>, {
    expect(@log.elems).to.be(0);
  }
}

describe 'arbitrary metadata-keyed hooks', :type<model>, {
  my @log;

  before-each {
    @log = ();
  }

  before-each :type<model>, {
    @log.push('model-setup');
  }

  it 'inherits the type from the describe block', {
    expect(@log[0]).to.be('model-setup');
  }

  context 'with a different type', :type<view>, {
    it 'does not trigger the model hook', {
      expect(@log.elems).to.be(0);
    }
  }
}

describe 'before-all and after-all with filters', {
  my @log;

  before-all :tag<expensive>, {
    @log.push('expensive-setup');
  }
  after-all :tag<expensive>, {
    @log.push('expensive-teardown');
  }

  context 'a group with a matching example', {
    it 'has at least one expensive example', :tag<expensive>, {
      expect(@log[0]).to.be('expensive-setup');
    }
  }

  it 'sees the before-all from the outer group', :tag<expensive>, {
    expect(@log.grep('expensive-setup').elems).to.be(1);
  }
}

describe 'before-all is skipped when no descendant example matches', {
  my @log;

  before-all :tag<missing>, {
    @log.push('should-not-fire');
  }

  it 'has no matching descendants', :tag<other>, {
    expect(@log.elems).to.be(0);
  }
}
