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
    my @captured = capture-failures {
      my $counter = 0;
      expect({ 1 + 1 }).to.change({ $counter });
    };
    my $count = @captured.elems;
    expect($count).to.be(1);
  }

  it 'fails when the block reads but does not mutate', {
    my @captured = capture-failures {
      my $counter = 5;
      expect({ my $tmp = $counter }).to.change({ $counter });
    };
    my $count = @captured.elems;
    expect($count).to.be(1);
  }

  it 'fails when the block mutates back to the original value', {
    my @captured = capture-failures {
      my $value = 1;
      expect({ $value = 2; $value = 1 }).to.change({ $value });
    };
    my $count = @captured.elems;
    expect($count).to.be(1);
  }

  it 'compares deep structures with eqv', {
    my @captured = capture-failures {
      my @items = 1, 2, 3;
      expect({ @items[0] = 1 }).to.change({ @items.clone });
    };
    my $count = @captured.elems;
    expect($count).to.be(1);
  }
}

describe 'change with non-Callable actuals', {
  it 'fails when given an Int', {
    my @captured = capture-failures {
      my $observable = 0;
      expect(42).to.change({ $observable });
    };
    my $count = @captured.elems;
    expect($count).to.be(1);
  }

  it 'fails when given a Str', {
    my @captured = capture-failures {
      my $observable = 0;
      expect('hello').to.change({ $observable });
    };
    my $count = @captured.elems;
    expect($count).to.be(1);
  }

  it 'fails when given Nil', {
    my @captured = capture-failures {
      my $observable = 0;
      expect(Nil).to.change({ $observable });
    };
    my $count = @captured.elems;
    expect($count).to.be(1);
  }

  it 'records a Callable-shape failure message for non-Callable actuals', {
    my @captured = capture-failures {
      my $observable = 0;
      expect(42).to.change({ $observable });
    };
    my $message = @captured[0].message;
    expect($message).to.be('expected a Callable for change, but got 42');
  }
}

describe 'change negation', {
  it 'passes when the block does not change the observable', {
    my $counter = 5;
    expect({ 1 + 1 }).to.not.change({ $counter });
  }

  it 'fails when the block changes under negation', {
    my @captured = capture-failures {
      my $counter = 0;
      expect({ $counter++ }).to.not.change({ $counter });
    };
    my $count = @captured.elems;
    expect($count).to.be(1);
  }

  it 'records a negated failure message naming both states', {
    my @captured = capture-failures {
      my $counter = 0;
      expect({ $counter = 7 }).to.not.change({ $counter });
    };
    my $message = @captured[0].message;
    my $negated = @captured[0].negated;
    expect($message).to.be(
      'expected block not to change observable, but it changed from 0 to 7'
    );
    expect($negated).to.be-truthy;
  }
}

describe 'change failure messages', {
  it 'records the no-change failure message when the value stays the same', {
    my @captured = capture-failures {
      my $counter = 3;
      expect({ 1 + 1 }).to.change({ $counter });
    };
    my $message = @captured[0].message;
    expect($message).to.be(
      'expected block to change observable, but it remained 3'
    );
  }
}

describe 'change preserves Failure tooling fields', {
  it 'preserves Failure.given as the action block', {
    my @captured = capture-failures {
      my $counter = 0;
      my &action = { 1 + 1 };
      expect(&action).to.change({ $counter });
    };
    my $given = @captured[0].given;
    expect($given ~~ Callable).to.be-truthy;
  }
}
