use BDD::Behave;

describe 'around-each wraps a single example', {
  my @log;

  before-each {
    @log.push('before');
  }
  after-each {
    @log.push('after');
  }
  around-each -> &continue {
    @log.push('around-start');
    continue();
    @log.push('around-end');
  }

  it 'fires around-start before before-each', {
    @log.push('body');
    my @from-current = @log[*-3 .. *-1];
    expect(@from-current[0]).to.be('around-start');
    expect(@from-current[1]).to.be('before');
    expect(@from-current[2]).to.be('body');
  }

  it 'records around-end and after between examples', {
    expect(@log.grep('around-end').elems > 0).to.be(True);
    expect(@log.grep('after').elems > 0).to.be(True);
  }
}

describe 'around-each composes outer-to-inner', {
  my @order;

  around-each -> &continue {
    @order.push('a-start');
    continue();
    @order.push('a-end');
  }
  around-each -> &continue {
    @order.push('b-start');
    continue();
    @order.push('b-end');
  }

  it 'first-registered hook is outermost', {
    @order.push('body');
    expect(@order[0]).to.be('a-start');
    expect(@order[1]).to.be('b-start');
    expect(@order[2]).to.be('body');
  }
}

describe 'nested around-each inheritance', {
  my @trace;

  around-each -> &continue {
    @trace.push('outer-start');
    continue();
    @trace.push('outer-end');
  }

  context 'inner context', {
    around-each -> &continue {
      @trace.push('inner-start');
      continue();
      @trace.push('inner-end');
    }

    it 'outer wraps inner', {
      @trace.push('body');
      expect(@trace[0]).to.be('outer-start');
      expect(@trace[1]).to.be('inner-start');
      expect(@trace[2]).to.be('body');
    }
  }
}

describe 'around-each cleanup with LEAVE', {
  my @resources;

  around-each -> &continue {
    @resources.push('open');
    LEAVE @resources.push('close');
    continue();
  }

  it 'opens before each example', {
    expect(@resources[*-1]).to.be('open');
  }

  it 'closes after the previous example', {
    expect(@resources.grep('close').elems > 0).to.be(True);
  }
}

describe 'tag-filtered around-each', {
  my @log;

  around-each :tag<db>, -> &continue {
    @log.push('db-begin');
    continue();
    @log.push('db-rollback');
  }

  it 'fires the wrapper for db-tagged examples', :tag<db>, {
    expect(@log[*-1]).to.be('db-begin');
  }

  it 'untagged example sees no new db hook fire', {
    my $count-before = @log.grep('db-begin').elems;
    expect($count-before).to.be(1);
  }
}

describe 'around-all wraps the whole group', {
  my $setup-count = 0;
  my $wrap-start = 0;

  around-all -> &continue {
    $wrap-start++;
    continue();
  }

  before-all {
    $setup-count++;
  }

  it 'around-all fires once before before-all', {
    expect($wrap-start).to.be(1);
    expect($setup-count).to.be(1);
  }

  it 'around-all fires only once across all examples', {
    expect($wrap-start).to.be(1);
  }
}
