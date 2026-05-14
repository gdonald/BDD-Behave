use BDD::Behave;
use BDD::Behave::Failures;

describe 'change.from', {
  it 'passes when the value started at the expected from value and changed', {
    my $counter = 0;
    expect({ $counter++ }).to.change({ $counter }).from(0);
  }

  it 'fails when the value did not start at the expected from value', {
    Failures.list = ();
    my $counter = 3;
    expect({ $counter++ }).to.change({ $counter }).from(0);
    my $count = Failures.list.elems;
    Failures.list = ();
    expect($count).to.be(1);
  }

  it 'records a "started as" failure message on from mismatch', {
    Failures.list = ();
    my $counter = 3;
    expect({ $counter++ }).to.change({ $counter }).from(0);
    my $message = Failures.list[0].message;
    Failures.list = ();
    expect($message).to.be(
      'expected block to change observable from 0, but it started as 3'
    );
  }

  it 'fails when the value did not change even though from matches', {
    Failures.list = ();
    my $value = 5;
    expect({ $value = 5 }).to.change({ $value }).from(5);
    my $count = Failures.list.elems;
    my $message = Failures.list[0].message;
    Failures.list = ();
    expect($count).to.be(1);
    expect($message).to.be(
      'expected block to change observable from 5, but it remained 5'
    );
  }

  it 'compares from with deep equality (eqv)', {
    my @items;
    expect({ @items.push: 'x' }).to.change({ @items.clone }).from([]);
  }
}

describe 'change.to', {
  it 'passes when the value ended at the expected to value', {
    my $counter = 0;
    expect({ $counter = 10 }).to.change({ $counter }).to(10);
  }

  it 'fails when the value did not end at the expected to value', {
    Failures.list = ();
    my $counter = 0;
    expect({ $counter = 7 }).to.change({ $counter }).to(10);
    my $count = Failures.list.elems;
    Failures.list = ();
    expect($count).to.be(1);
  }

  it 'records an "ended as" failure message on to mismatch', {
    Failures.list = ();
    my $counter = 0;
    expect({ $counter = 7 }).to.change({ $counter }).to(10);
    my $message = Failures.list[0].message;
    Failures.list = ();
    expect($message).to.be(
      'expected block to change observable to 10, but it ended as 7'
    );
  }

  it 'fails when the value did not change even though to matches', {
    Failures.list = ();
    my $value = 5;
    expect({ $value = 5 }).to.change({ $value }).to(5);
    my $count = Failures.list.elems;
    my $message = Failures.list[0].message;
    Failures.list = ();
    expect($count).to.be(1);
    expect($message).to.be(
      'expected block to change observable to 5, but it remained 5'
    );
  }
}

describe 'change.from.to', {
  it 'passes when the value transitioned from the expected start to the expected end', {
    my $counter = 0;
    expect({ $counter = 10 }).to.change({ $counter }).from(0).to(10);
  }

  it 'fails when from matches but to does not', {
    Failures.list = ();
    my $counter = 0;
    expect({ $counter = 7 }).to.change({ $counter }).from(0).to(10);
    my $count = Failures.list.elems;
    my $message = Failures.list[0].message;
    Failures.list = ();
    expect($count).to.be(1);
    expect($message).to.be(
      'expected block to change observable from 0 to 10, but it ended as 7'
    );
  }

  it 'fails when from does not match (to is irrelevant)', {
    Failures.list = ();
    my $counter = 3;
    expect({ $counter = 10 }).to.change({ $counter }).from(0).to(10);
    my $message = Failures.list[0].message;
    Failures.list = ();
    expect($message).to.be(
      'expected block to change observable from 0 to 10, but it started as 3'
    );
  }

  it 'fails when neither side changed even though both endpoints match', {
    Failures.list = ();
    my $value = 0;
    expect({ 1 + 1 }).to.change({ $value }).from(0).to(0);
    my $message = Failures.list[0].message;
    Failures.list = ();
    expect($message).to.be(
      'expected block to change observable from 0 to 0, but it remained 0'
    );
  }

  it 'composes with .to(...).from(...) in either order', {
    my $value = 1;
    expect({ $value = 2 }).to.change({ $value }).to(2).from(1);
  }

  it 'replaces a prior failure when a later chain step passes', {
    Failures.list = ();
    my $counter = 0;
    expect({ $counter = 10 }).to.change({ $counter }).from(99).to(10);
    my $count = Failures.list.elems;
    Failures.list = ();
    expect($count).to.be(1);
  }
}

describe 'change.from / change.to non-Callable actuals', {
  it 'records a Callable-shape failure even when from is set', {
    Failures.list = ();
    my $observable = 0;
    expect(42).to.change({ $observable }).from(0);
    my $message = Failures.list[0].message;
    Failures.list = ();
    expect($message).to.be('expected a Callable for change, but got 42');
  }
}

describe 'change.from / change.to negation', {
  it 'passes when negated and the value did not change to the expected target', {
    my $counter = 0;
    expect({ $counter = 7 }).to.not.change({ $counter }).from(0).to(10);
  }

  it 'fails when negated and the conjunction holds', {
    Failures.list = ();
    my $counter = 0;
    expect({ $counter = 10 }).to.not.change({ $counter }).from(0).to(10);
    my $count = Failures.list.elems;
    my $message = Failures.list[0].message;
    my $negated = Failures.list[0].negated;
    Failures.list = ();
    expect($count).to.be(1);
    expect($negated).to.be-truthy;
    expect($message).to.be(
      'expected block not to change observable from 0 to 10, but it changed from 0 to 10'
    );
  }
}

describe 'change.from / change.to Failure.expected metadata', {
  it 'preserves the [from, to] pair on Failure.expected when both specified', {
    Failures.list = ();
    my $counter = 0;
    expect({ $counter = 7 }).to.change({ $counter }).from(0).to(10);
    my $expected = Failures.list[0].expected;
    Failures.list = ();
    expect($expected).to.eq([0, 10]);
  }

  it 'preserves the from value on Failure.expected when only from specified', {
    Failures.list = ();
    my $counter = 3;
    expect({ $counter++ }).to.change({ $counter }).from(0);
    my $expected = Failures.list[0].expected;
    Failures.list = ();
    expect($expected).to.be(0);
  }

  it 'preserves the to value on Failure.expected when only to specified', {
    Failures.list = ();
    my $counter = 0;
    expect({ $counter = 7 }).to.change({ $counter }).to(10);
    my $expected = Failures.list[0].expected;
    Failures.list = ();
    expect($expected).to.be(10);
  }
}
