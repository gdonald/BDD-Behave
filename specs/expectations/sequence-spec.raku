use BDD::Behave;
use BDD::Behave::Failures;

describe 'start-with matcher on arrays', {
  it 'matches a single leading item', {
    expect([1, 2, 3]).to.start-with(1);
  }

  it 'matches multiple leading items in order', {
    expect([1, 2, 3]).to.start-with(1, 2);
  }

  it 'matches the entire array', {
    expect([1, 2, 3]).to.start-with(1, 2, 3);
  }

  it 'matches with strings', {
    expect(['a', 'b', 'c']).to.start-with('a', 'b');
  }

  it 'matches against List, not just Array', {
    expect((1, 2, 3)).to.start-with(1);
  }

  it 'matches nested elements via eqv', {
    expect([[1, 2], [3, 4]]).to.start-with([1, 2]);
  }

  it 'fails when first element differs', {
    my @captured = capture-failures {
      expect([1, 2, 3]).to.start-with(2);
    };
    expect(@captured.elems).to.be(1);
  }

  it 'fails when prefix items appear out of order', {
    my @captured = capture-failures {
      expect([1, 2, 3]).to.start-with(2, 1);
    };
    expect(@captured.elems).to.be(1);
  }

  it 'fails when expected prefix is longer than actual', {
    my @captured = capture-failures {
      expect([1]).to.start-with(1, 2);
    };
    expect(@captured.elems).to.be(1);
  }

  it 'records a matcher-supplied failure message', {
    my @captured = capture-failures {
      expect([1, 2, 3]).to.start-with(2);
    };
    my $message = @captured[0].message;
    expect($message).to.be('expected $[1, 2, 3] to start with 2');
  }

  it 'negation passes when prefix differs', {
    expect([1, 2, 3]).to.not.start-with(2);
  }

  it 'negation fails when prefix matches', {
    my @captured = capture-failures {
      expect([1, 2, 3]).to.not.start-with(1);
    };
    my $count = @captured.elems;
    my $message = @captured[0].message;
    my $negated = @captured[0].negated;
    expect($count).to.be(1);
    expect($message).to.be('expected $[1, 2, 3] not to start with 1');
    expect($negated).to.be-truthy;
  }
}

describe 'start-with matcher on strings', {
  it 'matches a single prefix', {
    expect('hello world').to.start-with('hello');
  }

  it 'matches multiple prefixes (each must be a prefix)', {
    expect('hello world').to.start-with('hello', 'h');
  }

  it 'matches the empty prefix', {
    expect('hello').to.start-with('');
  }

  it 'fails when prefix is missing', {
    my @captured = capture-failures {
      expect('hello world').to.start-with('world');
    };
    expect(@captured.elems).to.be(1);
  }

  it 'fails when one of multiple prefixes is missing', {
    my @captured = capture-failures {
      expect('hello world').to.start-with('hello', 'world');
    };
    expect(@captured.elems).to.be(1);
  }

  it 'negation passes when prefix is absent', {
    expect('hello world').to.not.start-with('world');
  }
}

describe 'start-with matcher edge cases', {
  it 'fails on undefined actual', {
    my @captured = capture-failures {
      expect(Any).to.start-with(1);
    };
    expect(@captured.elems).to.be(1);
  }

  it 'fails on non-iterable, non-string actual', {
    my @captured = capture-failures {
      expect(42).to.start-with(4);
    };
    expect(@captured.elems).to.be(1);
  }

  it 'requires at least one item', {
    my $error;
    try {
      expect([1, 2, 3]).to.start-with();
      CATCH { default { $error = .message } }
    }
    expect($error).to.be('start-with requires at least one item');
  }

  it 'preserves Failure.given and Failure.expected for tooling', {
    my @captured = capture-failures {
      expect([1, 2, 3]).to.start-with(99);
    };
    expect(@captured[0].given).to.be([1, 2, 3]);
    expect(@captured[0].expected).to.be([99]);
  }
}

describe 'end-with matcher on arrays', {
  it 'matches a single trailing item', {
    expect([1, 2, 3]).to.end-with(3);
  }

  it 'matches multiple trailing items in order', {
    expect([1, 2, 3]).to.end-with(2, 3);
  }

  it 'matches the entire array', {
    expect([1, 2, 3]).to.end-with(1, 2, 3);
  }

  it 'matches with strings', {
    expect(['a', 'b', 'c']).to.end-with('b', 'c');
  }

  it 'matches against List, not just Array', {
    expect((1, 2, 3)).to.end-with(3);
  }

  it 'matches nested elements via eqv', {
    expect([[1, 2], [3, 4]]).to.end-with([3, 4]);
  }

  it 'fails when last element differs', {
    my @captured = capture-failures {
      expect([1, 2, 3]).to.end-with(2);
    };
    expect(@captured.elems).to.be(1);
  }

  it 'fails when suffix items appear out of order', {
    my @captured = capture-failures {
      expect([1, 2, 3]).to.end-with(3, 2);
    };
    expect(@captured.elems).to.be(1);
  }

  it 'fails when expected suffix is longer than actual', {
    my @captured = capture-failures {
      expect([1]).to.end-with(1, 2);
    };
    expect(@captured.elems).to.be(1);
  }

  it 'records a matcher-supplied failure message', {
    my @captured = capture-failures {
      expect([1, 2, 3]).to.end-with(2);
    };
    my $message = @captured[0].message;
    expect($message).to.be('expected $[1, 2, 3] to end with 2');
  }

  it 'negation passes when suffix differs', {
    expect([1, 2, 3]).to.not.end-with(2);
  }

  it 'negation fails when suffix matches', {
    my @captured = capture-failures {
      expect([1, 2, 3]).to.not.end-with(3);
    };
    my $count = @captured.elems;
    my $message = @captured[0].message;
    my $negated = @captured[0].negated;
    expect($count).to.be(1);
    expect($message).to.be('expected $[1, 2, 3] not to end with 3');
    expect($negated).to.be-truthy;
  }
}

describe 'end-with matcher on strings', {
  it 'matches a single suffix', {
    expect('hello world').to.end-with('world');
  }

  it 'matches multiple suffixes (each must be a suffix)', {
    expect('hello world').to.end-with('world', 'd');
  }

  it 'matches the empty suffix', {
    expect('hello').to.end-with('');
  }

  it 'fails when suffix is missing', {
    my @captured = capture-failures {
      expect('hello world').to.end-with('hello');
    };
    expect(@captured.elems).to.be(1);
  }

  it 'fails when one of multiple suffixes is missing', {
    my @captured = capture-failures {
      expect('hello world').to.end-with('world', 'hello');
    };
    expect(@captured.elems).to.be(1);
  }

  it 'negation passes when suffix is absent', {
    expect('hello world').to.not.end-with('hello');
  }
}

describe 'end-with matcher edge cases', {
  it 'fails on undefined actual', {
    my @captured = capture-failures {
      expect(Any).to.end-with(1);
    };
    expect(@captured.elems).to.be(1);
  }

  it 'fails on non-iterable, non-string actual', {
    my @captured = capture-failures {
      expect(42).to.end-with(2);
    };
    expect(@captured.elems).to.be(1);
  }

  it 'requires at least one item', {
    my $error;
    try {
      expect([1, 2, 3]).to.end-with();
      CATCH { default { $error = .message } }
    }
    expect($error).to.be('end-with requires at least one item');
  }

  it 'preserves Failure.given and Failure.expected for tooling', {
    my @captured = capture-failures {
      expect([1, 2, 3]).to.end-with(99);
    };
    expect(@captured[0].given).to.be([1, 2, 3]);
    expect(@captured[0].expected).to.be([99]);
  }
}
