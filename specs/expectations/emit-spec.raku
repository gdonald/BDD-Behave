use BDD::Behave;
use BDD::Behave::Failures;

describe 'emit matcher with Supply', {
  it 'passes when the supply emits the expected values', {
    expect(Supply.from-list(1, 2, 3)).to.emit(1, 2, 3);
  }

  it 'passes when supply emits a single value', {
    expect(Supply.from-list('hello')).to.emit('hello');
  }

  it 'passes when supply emits typed values via eqv', {
    expect(Supply.from-list(1, 2.5, 'x')).to.emit(1, 2.5, 'x');
  }

  it 'fails when the supply emits different values', {
    my @captured = capture-failures {
      expect(Supply.from-list(1, 2, 4)).to.emit(1, 2, 3);
    };
    my $count = @captured.elems;
    expect($count).to.be(1);
  }

  it 'fails when the supply emits fewer values than expected', {
    my @captured = capture-failures {
      expect(Supply.from-list(1, 2)).to.emit(1, 2, 3, :within(0.2));
    };
    my $count = @captured.elems;
    expect($count).to.be(1);
  }

  it 'fails when given a non-stream actual', {
    my @captured = capture-failures {
      expect(42).to.emit(1, 2);
    };
    my $message = @captured[0].message;
    expect($message).to.include('expected a Supply or Channel');
    expect($message).to.include('42');
  }

  it 'reports the emitted values in the failure message', {
    my @captured = capture-failures {
      expect(Supply.from-list(1, 2, 4)).to.emit(1, 2, 3);
    };
    my $message = @captured[0].message;
    expect($message).to.include('expected stream to emit');
    expect($message).to.include('but it emitted');
  }

  it 'preserves the expected values on Failure', {
    my @captured = capture-failures {
      expect(Supply.from-list(1)).to.emit(1, 2);
    };
    my $expected = @captured[0].expected;
    expect($expected).to.eq([1, 2]);
  }
}

describe 'emit matcher with Channel', {
  it 'passes when channel emits the expected values', {
    my $ch = Channel.new;
    $ch.send(1);
    $ch.send(2);
    $ch.send(3);
    $ch.close;
    expect($ch).to.emit(1, 2, 3);
  }

  it 'fails when channel emits the wrong sequence', {
    my @captured = capture-failures {
      my $ch = Channel.new;
      $ch.send(1);
      $ch.send(9);
      $ch.close;
      expect($ch).to.emit(1, 2);
    };
    my $count = @captured.elems;
    expect($count).to.be(1);
  }
}

describe 'emit matcher with custom window', {
  it 'fails fast when a short window is configured', {
    my $start = now;
    capture-failures {
      expect(Supply.from-list(1)).to.emit(1, 2, 3, :within(0.1));
    };
    my $elapsed = now - $start;
    expect($elapsed).to.be-less-than(1);
  }
}

describe 'emit matcher negation', {
  it 'passes when the supply emits a different sequence', {
    expect(Supply.from-list(1, 2, 4)).to.not.emit(1, 2, 3);
  }

  it 'fails when the supply emits the expected sequence', {
    my @captured = capture-failures {
      expect(Supply.from-list(1, 2, 3)).to.not.emit(1, 2, 3);
    };
    my $count = @captured.elems;
    expect($count).to.be(1);
  }
}

describe 'emit-at-least matcher', {
  it 'passes when the supply emits at least n values', {
    expect(Supply.from-list(1, 2, 3, 4)).to.emit-at-least(2);
  }

  it 'passes when the supply emits exactly n values', {
    expect(Supply.from-list('a', 'b')).to.emit-at-least(2);
  }

  it 'fails when the supply emits fewer than n values', {
    my @captured = capture-failures {
      expect(Supply.from-list(1)).to.emit-at-least(2, :within(0.2));
    };
    my $count = @captured.elems;
    expect($count).to.be(1);
  }

  it 'works with Channels', {
    my $ch = Channel.new;
    $ch.send('a');
    $ch.send('b');
    $ch.send('c');
    $ch.close;
    expect($ch).to.emit-at-least(2);
  }

  it 'reports the emitted count in the failure message', {
    my @captured = capture-failures {
      expect(Supply.from-list(1)).to.emit-at-least(3, :within(0.2));
    };
    my $message = @captured[0].message;
    expect($message).to.include('emit at least 3');
    expect($message).to.include('but it emitted 1');
  }

  it 'preserves the minimum count on Failure', {
    my @captured = capture-failures {
      expect(Supply.from-list()).to.emit-at-least(2, :within(0.2));
    };
    my $expected = @captured[0].expected;
    expect($expected).to.be(2);
  }

  it 'fails when given a non-stream actual', {
    my @captured = capture-failures {
      expect('not a supply').to.emit-at-least(1);
    };
    my $message = @captured[0].message;
    expect($message).to.include('expected a Supply or Channel');
  }
}

describe 'emit-at-least negation', {
  it 'passes when the supply emits fewer than n values', {
    expect(Supply.from-list(1)).to.not.emit-at-least(3, :within(0.2));
  }

  it 'fails when the supply emits enough values', {
    my @captured = capture-failures {
      expect(Supply.from-list(1, 2, 3)).to.not.emit-at-least(2);
    };
    my $count = @captured.elems;
    expect($count).to.be(1);
  }
}

describe 'complete matcher', {
  it 'passes when the supply completes within the window', {
    expect(Supply.from-list(1, 2, 3)).to.complete;
  }

  it 'passes for an immediately-closed channel', {
    my $ch = Channel.new;
    $ch.close;
    expect($ch).to.complete;
  }

  it 'passes for a channel that closes after sending values', {
    my $ch = Channel.new;
    $ch.send(1);
    $ch.send(2);
    $ch.close;
    expect($ch).to.complete;
  }

  it 'fails when the supply does not complete', {
    my @captured = capture-failures {
      my $supplier = Supplier.new;
      expect($supplier.Supply).to.complete(:within(0.1));
    };
    my $count = @captured.elems;
    expect($count).to.be(1);
  }

  it 'reports the window in the failure message', {
    my @captured = capture-failures {
      my $supplier = Supplier.new;
      expect($supplier.Supply).to.complete(:within(0.1));
    };
    my $message = @captured[0].message;
    expect($message).to.include('complete within');
    expect($message).to.include('0.1');
    expect($message).to.include('still active');
  }

  it 'fails when given a non-stream actual', {
    my @captured = capture-failures {
      expect(42).to.complete;
    };
    my $message = @captured[0].message;
    expect($message).to.include('expected a Supply or Channel');
  }

  it 'preserves the window as expected-value on Failure', {
    my @captured = capture-failures {
      my $supplier = Supplier.new;
      expect($supplier.Supply).to.complete(:within(0.1));
    };
    my $expected = @captured[0].expected;
    expect($expected).to.be(0.1);
  }
}

describe 'complete negation', {
  it 'passes when the supply does not complete', {
    my $supplier = Supplier.new;
    expect($supplier.Supply).to.not.complete(:within(0.1));
  }

  it 'fails when the supply completes', {
    my @captured = capture-failures {
      expect(Supply.from-list(1, 2)).to.not.complete;
    };
    my $count = @captured.elems;
    expect($count).to.be(1);
  }
}
