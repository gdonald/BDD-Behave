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
    Failures.list = ();
    expect([1, 2, 3]).to.start-with(2);
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }

  it 'fails when prefix items appear out of order', {
    Failures.list = ();
    expect([1, 2, 3]).to.start-with(2, 1);
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }

  it 'fails when expected prefix is longer than actual', {
    Failures.list = ();
    expect([1]).to.start-with(1, 2);
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }

  it 'records a matcher-supplied failure message', {
    Failures.list = ();
    expect([1, 2, 3]).to.start-with(2);
    my $message = Failures.list[0].message;
    Failures.list = ();
    expect($message).to.be('expected $[1, 2, 3] to start with 2');
  }

  it 'negation passes when prefix differs', {
    expect([1, 2, 3]).to.not.start-with(2);
  }

  it 'negation fails when prefix matches', {
    Failures.list = ();
    expect([1, 2, 3]).to.not.start-with(1);
    my $count = Failures.list.elems;
    my $message = Failures.list[0].message;
    my $negated = Failures.list[0].negated;
    Failures.list = ();
    expect($count).to.be(1);
    expect($message).to.be('expected $[1, 2, 3] not to start with 1');
    expect($negated ?? 1 !! 0).to.be(1);
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
    Failures.list = ();
    expect('hello world').to.start-with('world');
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }

  it 'fails when one of multiple prefixes is missing', {
    Failures.list = ();
    expect('hello world').to.start-with('hello', 'world');
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }

  it 'negation passes when prefix is absent', {
    expect('hello world').to.not.start-with('world');
  }
}

describe 'start-with matcher edge cases', {
  it 'fails on undefined actual', {
    Failures.list = ();
    expect(Any).to.start-with(1);
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }

  it 'fails on non-iterable, non-string actual', {
    Failures.list = ();
    expect(42).to.start-with(4);
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
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
    Failures.list = ();
    expect([1, 2, 3]).to.start-with(99);
    expect(Failures.list[0].given).to.be([1, 2, 3]);
    expect(Failures.list[0].expected).to.be([99]);
    Failures.list = ();
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
    Failures.list = ();
    expect([1, 2, 3]).to.end-with(2);
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }

  it 'fails when suffix items appear out of order', {
    Failures.list = ();
    expect([1, 2, 3]).to.end-with(3, 2);
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }

  it 'fails when expected suffix is longer than actual', {
    Failures.list = ();
    expect([1]).to.end-with(1, 2);
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }

  it 'records a matcher-supplied failure message', {
    Failures.list = ();
    expect([1, 2, 3]).to.end-with(2);
    my $message = Failures.list[0].message;
    Failures.list = ();
    expect($message).to.be('expected $[1, 2, 3] to end with 2');
  }

  it 'negation passes when suffix differs', {
    expect([1, 2, 3]).to.not.end-with(2);
  }

  it 'negation fails when suffix matches', {
    Failures.list = ();
    expect([1, 2, 3]).to.not.end-with(3);
    my $count = Failures.list.elems;
    my $message = Failures.list[0].message;
    my $negated = Failures.list[0].negated;
    Failures.list = ();
    expect($count).to.be(1);
    expect($message).to.be('expected $[1, 2, 3] not to end with 3');
    expect($negated ?? 1 !! 0).to.be(1);
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
    Failures.list = ();
    expect('hello world').to.end-with('hello');
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }

  it 'fails when one of multiple suffixes is missing', {
    Failures.list = ();
    expect('hello world').to.end-with('world', 'hello');
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }

  it 'negation passes when suffix is absent', {
    expect('hello world').to.not.end-with('hello');
  }
}

describe 'end-with matcher edge cases', {
  it 'fails on undefined actual', {
    Failures.list = ();
    expect(Any).to.end-with(1);
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }

  it 'fails on non-iterable, non-string actual', {
    Failures.list = ();
    expect(42).to.end-with(2);
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
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
    Failures.list = ();
    expect([1, 2, 3]).to.end-with(99);
    expect(Failures.list[0].given).to.be([1, 2, 3]);
    expect(Failures.list[0].expected).to.be([99]);
    Failures.list = ();
  }
}
