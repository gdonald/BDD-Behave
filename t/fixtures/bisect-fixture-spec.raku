use BDD::Behave;

# Order-dependent fixture for bisect tests:
# `pollutes counter` mutates a module-level scalar; `expects counter to be zero`
# fails when (and only when) the polluter ran first in the same process.
# When run in isolation via --only-example, the polluter is excluded and the
# expectation passes.

my $counter = 0;

describe 'bisect fixture', :order<defined>, {
  it 'noop one', {
    expect(True).to.be-truthy;
  }

  it 'noop two', {
    expect(True).to.be-truthy;
  }

  it 'pollutes counter', {
    $counter++;
    expect(True).to.be-truthy;
  }

  it 'noop three', {
    expect(True).to.be-truthy;
  }

  it 'expects counter to be zero', {
    expect($counter).to.be(0);
  }
}
