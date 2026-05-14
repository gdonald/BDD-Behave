use BDD::Behave;
use BDD::Behave::Failures;

describe 'change.by', {
  it 'passes when the value changed by exactly the expected delta', {
    my $counter = 0;
    expect({ $counter += 5 }).to.change({ $counter }).by(5);
  }

  it 'passes for a negative delta when the value decreased by the expected amount', {
    my $counter = 10;
    expect({ $counter -= 3 }).to.change({ $counter }).by(-3);
  }

  it 'fails when the delta is smaller than expected', {
    Failures.list = ();
    my $counter = 0;
    expect({ $counter += 3 }).to.change({ $counter }).by(5);
    my $count = Failures.list.elems;
    Failures.list = ();
    expect($count).to.be(1);
  }

  it 'fails when the delta is larger than expected', {
    Failures.list = ();
    my $counter = 0;
    expect({ $counter += 7 }).to.change({ $counter }).by(5);
    my $count = Failures.list.elems;
    Failures.list = ();
    expect($count).to.be(1);
  }

  it 'records a "changed by" failure message on delta mismatch', {
    Failures.list = ();
    my $counter = 0;
    expect({ $counter += 3 }).to.change({ $counter }).by(5);
    my $message = Failures.list[0].message;
    Failures.list = ();
    expect($message).to.be(
      'expected block to change observable by 5, but it changed by 3'
    );
  }

  it 'fails as no-change when the value did not change even with by set', {
    Failures.list = ();
    my $counter = 5;
    expect({ 1 + 1 }).to.change({ $counter }).by(0);
    my $message = Failures.list[0].message;
    Failures.list = ();
    expect($message).to.be(
      'expected block to change observable by 0, but it remained 5'
    );
  }

  it 'supports Rat deltas', {
    my $balance = 10.0;
    expect({ $balance += 1.5 }).to.change({ $balance }).by(1.5);
  }

  it 'rejects non-numeric before/after values', {
    Failures.list = ();
    my $name = 'alice';
    expect({ $name = 'bob' }).to.change({ $name }).by(1);
    my $count = Failures.list.elems;
    Failures.list = ();
    expect($count).to.be(1);
  }
}

describe 'change.by-at-least', {
  it 'passes when the delta meets the minimum exactly', {
    my $counter = 0;
    expect({ $counter += 5 }).to.change({ $counter }).by-at-least(5);
  }

  it 'passes when the delta exceeds the minimum', {
    my $counter = 0;
    expect({ $counter += 10 }).to.change({ $counter }).by-at-least(5);
  }

  it 'fails when the delta falls short of the minimum', {
    Failures.list = ();
    my $counter = 0;
    expect({ $counter += 3 }).to.change({ $counter }).by-at-least(5);
    my $message = Failures.list[0].message;
    Failures.list = ();
    expect($message).to.be(
      'expected block to change observable by at least 5, but it changed by 3'
    );
  }

  it 'works with signed deltas: a negative actual fails by-at-least(0)', {
    Failures.list = ();
    my $counter = 10;
    expect({ $counter -= 3 }).to.change({ $counter }).by-at-least(0);
    my $count = Failures.list.elems;
    Failures.list = ();
    expect($count).to.be(1);
  }
}

describe 'change.by-at-most', {
  it 'passes when the delta meets the maximum exactly', {
    my $counter = 0;
    expect({ $counter += 5 }).to.change({ $counter }).by-at-most(5);
  }

  it 'passes when the delta is below the maximum', {
    my $counter = 0;
    expect({ $counter += 2 }).to.change({ $counter }).by-at-most(5);
  }

  it 'fails when the delta exceeds the maximum', {
    Failures.list = ();
    my $counter = 0;
    expect({ $counter += 7 }).to.change({ $counter }).by-at-most(5);
    my $message = Failures.list[0].message;
    Failures.list = ();
    expect($message).to.be(
      'expected block to change observable by at most 5, but it changed by 7'
    );
  }

  it 'allows decreases when the maximum is positive', {
    my $counter = 10;
    expect({ $counter -= 3 }).to.change({ $counter }).by-at-most(5);
  }
}

describe 'change.by combined with .from / .to', {
  it 'composes .from(0).by(5)', {
    my $counter = 0;
    expect({ $counter += 5 }).to.change({ $counter }).from(0).by(5);
  }

  it 'fails when .from matches but .by does not', {
    Failures.list = ();
    my $counter = 0;
    expect({ $counter += 3 }).to.change({ $counter }).from(0).by(5);
    my $message = Failures.list[0].message;
    Failures.list = ();
    expect($message).to.be(
      'expected block to change observable from 0 by 5, but it changed by 3'
    );
  }

  it 'fails when .from does not match (delta is irrelevant)', {
    Failures.list = ();
    my $counter = 99;
    expect({ $counter += 5 }).to.change({ $counter }).from(0).by(5);
    my $message = Failures.list[0].message;
    Failures.list = ();
    expect($message).to.be(
      'expected block to change observable from 0 by 5, but it started as 99'
    );
  }
}

describe 'change.by chain composition', {
  it 'replaces a prior failure when a later chain step passes', {
    Failures.list = ();
    my $counter = 0;
    expect({ $counter += 5 }).to.change({ $counter }).by(99).by(5);
    my $count = Failures.list.elems;
    Failures.list = ();
    expect($count).to.be(0);
  }

  it 'AND-combines multiple by-modifiers when all set', {
    my $counter = 0;
    expect({ $counter += 5 }).to.change({ $counter })
      .by-at-least(1).by-at-most(10);
  }

  it 'fails when any of the combined by-modifiers does not hold', {
    Failures.list = ();
    my $counter = 0;
    expect({ $counter += 15 }).to.change({ $counter })
      .by-at-least(1).by-at-most(10);
    my $count = Failures.list.elems;
    Failures.list = ();
    expect($count).to.be(1);
  }

  it 'runs the block exactly once across chained by-modifiers', {
    Failures.list = ();
    my $run-count = 0;
    my $value = 0;
    expect({ $run-count++; $value += 5 }).to.change({ $value }).by(5);
    Failures.list = ();
    expect($run-count).to.be(1);
  }
}

describe 'change.by non-Callable actuals', {
  it 'records a Callable-shape failure even when by is set', {
    Failures.list = ();
    my $observable = 0;
    expect(42).to.change({ $observable }).by(5);
    my $message = Failures.list[0].message;
    Failures.list = ();
    expect($message).to.be('expected a Callable for change, but got 42');
  }
}

describe 'change.by negation', {
  it 'passes when negated and the delta does not match', {
    my $counter = 0;
    expect({ $counter += 3 }).to.not.change({ $counter }).by(5);
  }

  it 'fails when negated and the delta matches', {
    Failures.list = ();
    my $counter = 0;
    expect({ $counter += 5 }).to.not.change({ $counter }).by(5);
    my $count = Failures.list.elems;
    my $message = Failures.list[0].message;
    my $negated = Failures.list[0].negated;
    Failures.list = ();
    expect($count).to.be(1);
    expect($negated).to.be-truthy;
    expect($message).to.be(
      'expected block not to change observable by 5, but it changed from 0 to 5'
    );
  }
}

describe 'change.by Failure.expected metadata', {
  it 'preserves the by value on Failure.expected', {
    Failures.list = ();
    my $counter = 0;
    expect({ $counter += 3 }).to.change({ $counter }).by(5);
    my $expected = Failures.list[0].expected;
    Failures.list = ();
    expect($expected).to.be(5);
  }

  it 'preserves the by-at-least value on Failure.expected', {
    Failures.list = ();
    my $counter = 0;
    expect({ $counter += 3 }).to.change({ $counter }).by-at-least(5);
    my $expected = Failures.list[0].expected;
    Failures.list = ();
    expect($expected).to.be(5);
  }

  it 'preserves the by-at-most value on Failure.expected', {
    Failures.list = ();
    my $counter = 0;
    expect({ $counter += 7 }).to.change({ $counter }).by-at-most(5);
    my $expected = Failures.list[0].expected;
    Failures.list = ();
    expect($expected).to.be(5);
  }

  it 'preserves the [from, to] pair when from/to/by all set', {
    Failures.list = ();
    my $counter = 0;
    expect({ $counter += 3 }).to.change({ $counter }).from(0).to(10).by(5);
    my $expected = Failures.list[0].expected;
    Failures.list = ();
    expect($expected).to.eq([0, 10]);
  }
}
