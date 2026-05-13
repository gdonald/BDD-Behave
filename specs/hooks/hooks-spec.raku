use BDD::Behave;

describe 'before-each and after-each hooks', {
  my @log;

  before-each {
    @log.push('before-each');
  }

  after-each {
    @log.push('after-each');
  }

  it 'runs before-each before the example body', {
    @log.push('example-1');
    expect(@log[*-2]).to.be('before-each');
  }

  it 'records both phases per example', {
    expect(@log.grep('before-each').elems > 0).to.be-truthy;
  }
}

describe 'before-all and after-all hooks', {
  my $setup-count = 0;
  my $teardown-count = 0;

  before-all {
    $setup-count++;
  }

  after-all {
    $teardown-count++;
  }

  it 'sets up once before all examples', {
    expect($setup-count).to.be(1);
  }

  it 'before-all does not fire again between examples', {
    expect($setup-count).to.be(1);
  }
}

describe 'hook ordering with multiple hooks', {
  my @order;

  before-each { @order.push('first-before') }
  before-each { @order.push('second-before') }
  after-each  { @order.push('first-after')  }
  after-each  { @order.push('second-after') }

  it 'runs hooks in registration order', {
    expect(@order[0]).to.be('first-before');
    expect(@order[1]).to.be('second-before');
  }
}

describe 'nested hook inheritance', {
  my @trace;

  before-each { @trace.push('outer-before') }
  after-each  { @trace.push('outer-after')  }

  context 'inner context', {
    before-each { @trace.push('inner-before') }
    after-each  { @trace.push('inner-after')  }

    it 'inherits outer before-each before inner before-each', {
      my @recent = @trace[*-2, *-1];
      expect(@recent[0]).to.be('outer-before');
      expect(@recent[1]).to.be('inner-before');
    }
  }
}

describe 'hooks operating on shared state', {
  my $counter;

  before-each {
    $counter = 0;
  }

  it 'starts each example with reset state', {
    $counter += 5;
    expect($counter).to.be(5);
  }

  it 'next example sees freshly reset state', {
    expect($counter).to.be(0);
    $counter += 7;
    expect($counter).to.be(7);
  }
}
