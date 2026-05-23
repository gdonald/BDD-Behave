use BDD::Behave;
use BDD::Behave::Failures;

describe 'eq matcher (order-dependent structural equality)', {
  it 'matches identical arrays', {
    expect([1, 2, 3]).to.eq([1, 2, 3]);
  }

  it 'matches identical Lists', {
    expect((1, 2, 3)).to.eq((1, 2, 3));
  }

  it 'distinguishes Array from List (eqv is type-strict)', {
    my @captured = capture-failures {
      expect([1, 2, 3]).to.eq((1, 2, 3));
    };
    expect(@captured.elems).to.be(1);
  }

  it 'matches nested arrays', {
    expect([[1, 2], [3, 4]]).to.eq([[1, 2], [3, 4]]);
  }

  it 'matches hashes', {
    expect({ a => 1, b => 2 }).to.eq({ a => 1, b => 2 });
  }

  it 'matches scalars', {
    expect(42).to.eq(42);
    expect('hello').to.eq('hello');
  }

  it 'fails when arrays differ in order', {
    my @captured = capture-failures {
      expect([1, 2, 3]).to.eq([3, 2, 1]);
    };
    expect(@captured.elems).to.be(1);
  }

  it 'fails when arrays have different elements', {
    my @captured = capture-failures {
      expect([1, 2, 3]).to.eq([1, 2, 4]);
    };
    expect(@captured.elems).to.be(1);
  }

  it 'fails when arrays have different lengths', {
    my @captured = capture-failures {
      expect([1, 2, 3]).to.eq([1, 2]);
    };
    expect(@captured.elems).to.be(1);
  }

  it 'fails when nested arrays differ', {
    my @captured = capture-failures {
      expect([[1, 2], [3, 4]]).to.eq([[1, 2], [3, 5]]);
    };
    expect(@captured.elems).to.be(1);
  }

  it 'distinguishes Range from List with same elements', {
    my @captured = capture-failures {
      expect((1, 2, 3)).to.eq(1..3);
    };
    expect(@captured.elems).to.be(1);
  }

  it 'negation passes when values differ', {
    expect([1, 2, 3]).to.not.eq([3, 2, 1]);
  }

  it 'negation fails when values are equal', {
    my @captured = capture-failures {
      expect([1, 2, 3]).to.not.eq([1, 2, 3]);
    };
    my $count = @captured.elems;
    my $negated = @captured[0].negated;
    expect($count).to.be(1);
    expect($negated).to.be-truthy;
  }

  it 'preserves Failure.given and Failure.expected for tooling', {
    my @captured = capture-failures {
      expect([1, 2, 3]).to.eq([1, 2, 4]);
    };
    expect(@captured[0].given).to.be([1, 2, 3]);
    expect(@captured[0].expected).to.be([1, 2, 4]);
  }
}

describe 'contain-exactly matcher (order-independent multiset equality)', {
  it 'matches the same elements in same order', {
    expect([1, 2, 3]).to.contain-exactly(1, 2, 3);
  }

  it 'matches the same elements in different order', {
    expect([1, 2, 3]).to.contain-exactly(3, 1, 2);
  }

  it 'matches with strings', {
    expect(['a', 'b', 'c']).to.contain-exactly('c', 'a', 'b');
  }

  it 'matches Lists', {
    expect((1, 2, 3)).to.contain-exactly(2, 3, 1);
  }

  it 'matches nested elements via eqv', {
    expect([[1, 2], [3, 4]]).to.contain-exactly([3, 4], [1, 2]);
  }

  it 'matches an empty array against an empty expectation', {
    expect([]).to.contain-exactly();
  }

  it 'preserves duplicates (multiset semantics)', {
    expect([1, 1, 2]).to.contain-exactly(1, 2, 1);
  }

  it 'fails when element counts differ', {
    my @captured = capture-failures {
      expect([1, 1, 2]).to.contain-exactly(1, 2);
    };
    expect(@captured.elems).to.be(1);
  }

  it 'fails when actual has extra elements', {
    my @captured = capture-failures {
      expect([1, 2, 3, 4]).to.contain-exactly(1, 2, 3);
    };
    expect(@captured.elems).to.be(1);
  }

  it 'fails when expected has extra elements', {
    my @captured = capture-failures {
      expect([1, 2]).to.contain-exactly(1, 2, 3);
    };
    expect(@captured.elems).to.be(1);
  }

  it 'fails when an element is missing', {
    my @captured = capture-failures {
      expect([1, 2, 3]).to.contain-exactly(1, 2, 99);
    };
    expect(@captured.elems).to.be(1);
  }

  it 'fails on undefined actual', {
    my @captured = capture-failures {
      expect(Any).to.contain-exactly(1);
    };
    expect(@captured.elems).to.be(1);
  }

  it 'fails on non-iterable actual', {
    my @captured = capture-failures {
      expect(42).to.contain-exactly(42);
    };
    expect(@captured.elems).to.be(1);
  }

  it 'records a matcher-supplied failure message', {
    my @captured = capture-failures {
      expect([1, 2, 3]).to.contain-exactly(1, 2);
    };
    my $message = @captured[0].message;
    expect($message).to.be('expected $[1, 2, 3] to contain exactly 1, 2');
  }

  it 'negation passes when elements differ', {
    expect([1, 2, 3]).to.not.contain-exactly(1, 2);
  }

  it 'negation fails when elements match (any order)', {
    my @captured = capture-failures {
      expect([1, 2, 3]).to.not.contain-exactly(3, 2, 1);
    };
    my $count = @captured.elems;
    my $message = @captured[0].message;
    my $negated = @captured[0].negated;
    expect($count).to.be(1);
    expect($message).to.be('expected $[1, 2, 3] not to contain exactly 3, 2, 1');
    expect($negated).to.be-truthy;
  }

  it 'preserves Failure.given and Failure.expected for tooling', {
    my @captured = capture-failures {
      expect([1, 2, 3]).to.contain-exactly(1, 2);
    };
    expect(@captured[0].given).to.be([1, 2, 3]);
    expect(@captured[0].expected.elems).to.be(2);
  }
}

describe 'match-array matcher (alias for contain-exactly)', {
  it 'matches when arrays contain the same elements', {
    expect([1, 2, 3]).to.match-array([3, 2, 1]);
  }

  it 'matches when actual is a List and expected is an Array', {
    expect((1, 2, 3)).to.match-array([2, 3, 1]);
  }

  it 'matches an empty array against an empty array', {
    expect([]).to.match-array([]);
  }

  it 'fails when element counts differ', {
    my @captured = capture-failures {
      expect([1, 1, 2]).to.match-array([1, 2]);
    };
    expect(@captured.elems).to.be(1);
  }

  it 'fails when an element is missing', {
    my @captured = capture-failures {
      expect([1, 2, 3]).to.match-array([1, 2, 99]);
    };
    expect(@captured.elems).to.be(1);
  }

  it 'records the same failure-message format as contain-exactly', {
    my @captured = capture-failures {
      expect([1, 2, 3]).to.match-array([1, 2]);
    };
    my $message = @captured[0].message;
    expect($message).to.be('expected $[1, 2, 3] to contain exactly 1, 2');
  }

  it 'negation passes when arrays differ', {
    expect([1, 2, 3]).to.not.match-array([1, 2]);
  }

  it 'requires an array argument', {
    my $error;
    try {
      expect([1, 2, 3]).to.match-array(42);
      CATCH { default { $error = .message } }
    }
    expect($error).to.be('match-array requires an array argument');
  }
}
