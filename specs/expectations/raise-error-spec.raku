use BDD::Behave;
use BDD::Behave::Failures;

describe 'raise-error matcher basics', {
  it 'passes when the block raises with die', {
    expect({ die "boom" }).to.raise-error;
  }

  it 'passes when the block throws a typed exception', {
    expect({ X::AdHoc.new(payload => 'oops').throw }).to.raise-error;
  }

  it 'passes when an exception propagates from nested code', {
    my sub inner { die "nested" }
    expect({ inner() }).to.raise-error;
  }

  it 'fails when the block does not raise', {
    Failures.list = ();
    expect({ 1 + 1 }).to.raise-error;
    my $count = Failures.list.elems;
    Failures.list = ();
    expect($count).to.be(1);
  }

  it 'fails when the block returns normally with a value', {
    Failures.list = ();
    expect({ 'all good' }).to.raise-error;
    my $count = Failures.list.elems;
    Failures.list = ();
    expect($count).to.be(1);
  }

  it 'records a matcher-supplied failure message on the no-error case', {
    Failures.list = ();
    expect({ 42 }).to.raise-error;
    my $message = Failures.list[0].message;
    Failures.list = ();
    expect($message).to.be(
      'expected block to raise an error, but none was raised'
    );
  }
}

describe 'raise-error with non-Callable actuals', {
  it 'fails when given an Int', {
    Failures.list = ();
    expect(42).to.raise-error;
    my $count = Failures.list.elems;
    Failures.list = ();
    expect($count).to.be(1);
  }

  it 'fails when given a Str', {
    Failures.list = ();
    expect('hello').to.raise-error;
    my $count = Failures.list.elems;
    Failures.list = ();
    expect($count).to.be(1);
  }

  it 'fails when given Nil', {
    Failures.list = ();
    expect(Nil).to.raise-error;
    my $count = Failures.list.elems;
    Failures.list = ();
    expect($count).to.be(1);
  }

  it 'records a Callable-shape message for non-Callable actuals', {
    Failures.list = ();
    expect(42).to.raise-error;
    my $message = Failures.list[0].message;
    Failures.list = ();
    expect($message).to.be('expected a Callable for raise-error, but got 42');
  }
}

describe 'raise-error negation', {
  it 'passes when the block does not raise', {
    expect({ 1 + 1 }).to.not.raise-error;
  }

  it 'fails when the block raises under negation', {
    Failures.list = ();
    expect({ die "boom" }).to.not.raise-error;
    my $count = Failures.list.elems;
    Failures.list = ();
    expect($count).to.be(1);
  }

  it 'records a negated failure message that includes the exception detail', {
    Failures.list = ();
    expect({ die "boom" }).to.not.raise-error;
    my $message = Failures.list[0].message;
    my $negated = Failures.list[0].negated;
    Failures.list = ();
    expect($message).to.include(
      'expected block not to raise an error, but one was raised'
    );
    expect($message).to.include('X::AdHoc');
    expect($message).to.include('boom');
    expect($negated).to.be-truthy;
  }
}

describe 'raise-error preserves Failure metadata', {
  it 'preserves Failure.given as the block when no error is raised', {
    Failures.list = ();
    my $block = { 99 };
    expect($block).to.raise-error;
    my $given = Failures.list[0].given;
    Failures.list = ();
    expect($given ~~ Callable).to.be-truthy;
  }

  it 'records negated when called via .not', {
    Failures.list = ();
    expect({ die "x" }).to.not.raise-error;
    my $negated = Failures.list[0].negated;
    Failures.list = ();
    expect($negated).to.be-truthy;
  }
}
