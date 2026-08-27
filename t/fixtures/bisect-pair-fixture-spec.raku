use BDD::Behave;

# Order-dependent fixture whose failure needs two prior examples: the counter
# only passes the limit when both incrementing examples ran first. Neither half
# of the prior list reproduces it on its own, so bisecting has to prune the
# list one example at a time.

my $counter = 0;

describe 'bisect pair fixture', :order<defined>, {
  it 'increments once', {
    $counter++;
    expect(True).to.be-truthy;
  }

  it 'noop one', {
    expect(True).to.be-truthy;
  }

  it 'increments again', {
    $counter++;
    expect(True).to.be-truthy;
  }

  it 'noop two', {
    expect(True).to.be-truthy;
  }

  it 'expects counter to be at most one', {
    expect($counter).to.be-lte(1);
  }
}
