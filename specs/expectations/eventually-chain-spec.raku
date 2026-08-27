use BDD::Behave;

# Every matcher the eventually builder chains is reached here, since a spec
# written against `expect` only ever exercises the few it needs.
describe 'the matchers an eventually chain accepts', {
  it 'takes a value to be', {
    expect({ 'ready' }).to.eventually.be('ready');
  }

  it 'takes a value to equal', {
    expect({ 'ready' }).to.eventually.eq('ready');
  }

  it 'takes a truthiness check', {
    expect({ 1 }).to.eventually.be-truthy;
  }

  it 'takes a falsiness check', {
    expect({ 0 }).to.eventually.be-falsy;
  }

  it 'takes a nil check', {
    expect({ Nil }).to.eventually.be-nil;
  }

  it 'takes a pattern', {
    expect({ 'ready to go' }).to.eventually.match(/'to go'/);
  }

  it 'takes an item a list must hold', {
    expect({ [1, 2, 3] }).to.eventually.include(2);
  }

  it 'takes the exact items of a list', {
    expect({ [1, 2] }).to.eventually.contain-exactly(1, 2);
  }

  it 'takes an array to compare against', {
    expect({ [1, 2] }).to.eventually.match-array([1, 2]);
  }

  it 'takes the items a list must start with', {
    expect({ [1, 2, 3] }).to.eventually.start-with(1);
  }

  it 'takes the items a list must end with', {
    expect({ [1, 2, 3] }).to.eventually.end-with(3);
  }

  it 'takes a type', {
    expect({ 'a string' }).to.eventually.be-a(Str);
  }

  it 'takes a type written with an article', {
    expect({ 42 }).to.eventually.be-an(Int);
  }

  it 'takes a lower bound that excludes the value', {
    expect({ 5 }).to.eventually.be-greater-than(1);
  }

  it 'takes that bound written short', {
    expect({ 5 }).to.eventually.be-gt(1);
  }

  it 'takes a lower bound that includes the value', {
    expect({ 5 }).to.eventually.be-greater-than-or-equal-to(5);
  }

  it 'takes that bound written short', {
    expect({ 5 }).to.eventually.be-gte(5);
  }

  it 'takes an upper bound that excludes the value', {
    expect({ 5 }).to.eventually.be-less-than(9);
  }

  it 'takes that bound written short', {
    expect({ 5 }).to.eventually.be-lt(9);
  }

  it 'takes an upper bound that includes the value', {
    expect({ 5 }).to.eventually.be-less-than-or-equal-to(5);
  }

  it 'takes that bound written short', {
    expect({ 5 }).to.eventually.be-lte(5);
  }
}

describe 'an eventually chain reading a value that settles late', {
  it 'waits for the value to arrive', {
    my $value = 0;
    start { sleep 0.05; $value = 7 }

    expect({ $value }).to.eventually(:timeout(2)).be(7);
  }
}

describe 'an eventually chain that was not wanted to match', {
  it 'passes when the value never arrives', {
    expect({ 'never ready' }).to.eventually(:timeout(0.2)).not.be('ready');
  }
}

describe 'an eventually chain given a matcher name nothing registered', {
  it 'refuses the call', {
    expect({ expect({ 1 }).to.eventually.be-completely-made-up })
      .to.raise-error(X::Method::NotFound);
  }
}

describe 'an eventually chain given a custom matcher', {
  # Registering inside the example rather than at load time, since the registry
  # is process-wide and another spec file clears it while examples run.
  before-each {
    define-matcher 'eventually-chain-be-ready',
      match => -> $actual { $actual eq 'ready' };
  }

  it 'takes it by name', {
    expect({ 'ready' }).to.eventually.eventually-chain-be-ready;
  }
}

describe 'the arguments an eventually chain refuses', {
  it 'refuses an include with nothing to look for', {
    expect({ expect({ [1] }).to.eventually.include }).to.raise-error(/'requires at least one item'/);
  }

  it 'refuses a match-array against something that is not an array', {
    expect({ expect({ [1] }).to.eventually.match-array('not an array') })
      .to.raise-error(/'requires an array argument'/);
  }

  it 'refuses a start-with with nothing to look for', {
    expect({ expect({ [1] }).to.eventually.start-with })
      .to.raise-error(/'requires at least one item'/);
  }

  it 'refuses an end-with with nothing to look for', {
    expect({ expect({ [1] }).to.eventually.end-with })
      .to.raise-error(/'requires at least one item'/);
  }
}
