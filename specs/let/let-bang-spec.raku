use BDD::Behave;

my $eager-counter = 0;
my $lazy-counter  = 0;

describe 'let-bang vs let with side effects', :order<defined>, {
  let-bang(:eager, { ++$eager-counter });
  let(:lazy,       { ++$lazy-counter });

  it 'forces eager evaluation before each example', {
    expect($eager-counter).to.be(1);
  }

  it 'still increments eager between examples', {
    expect($eager-counter).to.be(2);
  }

  it 'leaves lazy untouched until first read', {
    expect($lazy-counter).to.be(0);
    expect(:lazy).to.be($lazy-counter);
  }
}

describe 'let-bang memoization within an example', {
  my $hits = 0;
  let-bang(:value, { ++$hits });

  it 'evaluates exactly once per example', {
    expect(:value).to.be(:value);
    expect($hits).to.be(1);
  }
}

describe 'let-bang with string-name form', {
  my $touched = 0;
  let-bang('eagerly', { ++$touched });

  it 'is forced before the example body', {
    expect($touched).to.be(1);
    expect(:eagerly).to.be(1);
  }
}

describe 'let-bang inheritance to nested contexts', {
  my $nested-counter = 0;
  let-bang(:outer-eager, { ++$nested-counter });

  context 'inside a nested context', {
    it 'still evaluates eagerly for the inner example', {
      expect($nested-counter).to.be(1);
      expect(:outer-eager).to.be(1);
    }
  }
}

describe 'let-bang ordering with regular before-each', {
  my @log;
  before-each { @log.push('before-each') };
  let-bang(:eager-log, { @log.push('let-bang'); 'value' });

  it 'fires alongside before-each in declaration order', {
    expect(@log.elems).to.be(2);
    expect(@log[0]).to.be('before-each');
    expect(@log[1]).to.be('let-bang');
  }
}

describe 'multiple let-bang declarations', {
  my @order;
  let-bang(:first,  { @order.push('first');  1 });
  let-bang(:second, { @order.push('second'); 2 });

  it 'evaluates each in declaration order', {
    expect(@order.elems).to.be(2);
    expect(@order[0]).to.be('first');
    expect(@order[1]).to.be('second');
    expect(:first).to.be(1);
    expect(:second).to.be(2);
  }
}

describe 'inner let-bang shadows outer let-bang', {
  my $outer-hits = 0;
  my $inner-hits = 0;
  let-bang(:value, { ++$outer-hits; 'outer' });

  context 'inner context with shadowing let-bang', {
    let-bang(:value, { ++$inner-hits; 'inner' });

    it 'inner block runs and outer block is shadowed for reads', {
      expect($outer-hits).to.be(0);
      expect($inner-hits).to.be(1);
      expect(:value).to.be('inner');
    }
  }
}
