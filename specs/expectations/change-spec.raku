use BDD::Behave;
use BDD::Behave::Failures;

describe 'change matcher basics', {
  it 'passes when the block changes the observable', {
    my $counter = 0;
    expect({ $counter++ }).to.change({ $counter });
  }

  it 'passes when the block mutates an array', {
    my @items;
    expect({ @items.push: 'x' }).to.change({ @items.elems });
  }

  it 'passes when the block mutates a hash', {
    my %store;
    expect({ %store<key> = 'value' }).to.change({ %store.elems });
  }

  it 'passes when the change is in a string', {
    my $message = 'hello';
    expect({ $message ~= ' world' }).to.change({ $message });
  }

  it 'passes when the observable transitions from undefined to defined', {
    my $value;
    expect({ $value = 42 }).to.change({ $value });
  }

  it 'fails when the block does not change the observable', {
    Failures.list = ();
    my $counter = 0;
    expect({ 1 + 1 }).to.change({ $counter });
    my $count = Failures.list.elems;
    Failures.list = ();
    expect($count).to.be(1);
  }

  it 'fails when the block reads but does not mutate', {
    Failures.list = ();
    my $counter = 5;
    expect({ my $tmp = $counter }).to.change({ $counter });
    my $count = Failures.list.elems;
    Failures.list = ();
    expect($count).to.be(1);
  }

  it 'fails when the block mutates back to the original value', {
    Failures.list = ();
    my $value = 1;
    expect({ $value = 2; $value = 1 }).to.change({ $value });
    my $count = Failures.list.elems;
    Failures.list = ();
    expect($count).to.be(1);
  }

  it 'compares deep structures with eqv', {
    Failures.list = ();
    my @items = 1, 2, 3;
    expect({ @items[0] = 1 }).to.change({ @items.clone });
    my $count = Failures.list.elems;
    Failures.list = ();
    expect($count).to.be(1);
  }
}

describe 'change with non-Callable actuals', {
  it 'fails when given an Int', {
    Failures.list = ();
    my $observable = 0;
    expect(42).to.change({ $observable });
    my $count = Failures.list.elems;
    Failures.list = ();
    expect($count).to.be(1);
  }

  it 'fails when given a Str', {
    Failures.list = ();
    my $observable = 0;
    expect('hello').to.change({ $observable });
    my $count = Failures.list.elems;
    Failures.list = ();
    expect($count).to.be(1);
  }

  it 'fails when given Nil', {
    Failures.list = ();
    my $observable = 0;
    expect(Nil).to.change({ $observable });
    my $count = Failures.list.elems;
    Failures.list = ();
    expect($count).to.be(1);
  }

  it 'records a Callable-shape failure message for non-Callable actuals', {
    Failures.list = ();
    my $observable = 0;
    expect(42).to.change({ $observable });
    my $message = Failures.list[0].message;
    Failures.list = ();
    expect($message).to.be('expected a Callable for change, but got 42');
  }
}

describe 'change negation', {
  it 'passes when the block does not change the observable', {
    my $counter = 5;
    expect({ 1 + 1 }).to.not.change({ $counter });
  }

  it 'fails when the block changes under negation', {
    Failures.list = ();
    my $counter = 0;
    expect({ $counter++ }).to.not.change({ $counter });
    my $count = Failures.list.elems;
    Failures.list = ();
    expect($count).to.be(1);
  }

  it 'records a negated failure message naming both states', {
    Failures.list = ();
    my $counter = 0;
    expect({ $counter = 7 }).to.not.change({ $counter });
    my $message = Failures.list[0].message;
    my $negated = Failures.list[0].negated;
    Failures.list = ();
    expect($message).to.be(
      'expected block not to change observable, but it changed from 0 to 7'
    );
    expect($negated).to.be-truthy;
  }
}

describe 'change failure messages', {
  it 'records the no-change failure message when the value stays the same', {
    Failures.list = ();
    my $counter = 3;
    expect({ 1 + 1 }).to.change({ $counter });
    my $message = Failures.list[0].message;
    Failures.list = ();
    expect($message).to.be(
      'expected block to change observable, but it remained 3'
    );
  }
}

describe 'change preserves Failure tooling fields', {
  it 'preserves Failure.given as the action block', {
    Failures.list = ();
    my $counter = 0;
    my &action = { 1 + 1 };
    expect(&action).to.change({ $counter });
    my $given = Failures.list[0].given;
    Failures.list = ();
    expect($given ~~ Callable).to.be-truthy;
  }
}
