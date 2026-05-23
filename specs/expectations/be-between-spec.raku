use BDD::Behave;
use BDD::Behave::Failures;

describe 'be-between matcher', {
  it 'passes when actual is within inclusive bounds', {
    expect(5).to.be-between(1, 10);
  }

  it 'passes when actual equals the lower bound (inclusive default)', {
    expect(1).to.be-between(1, 10);
  }

  it 'passes when actual equals the upper bound (inclusive default)', {
    expect(10).to.be-between(1, 10);
  }

  it 'fails when actual is below the lower bound', {
    my @captured = capture-failures {
      expect(0).to.be-between(1, 10);
    };
    expect(@captured.elems).to.be(1);
  }

  it 'fails when actual is above the upper bound', {
    my @captured = capture-failures {
      expect(11).to.be-between(1, 10);
    };
    expect(@captured.elems).to.be(1);
  }

  it 'works with Rat values', {
    expect(1.5).to.be-between(1.0, 2.0);
  }

  it 'works with Num values', {
    expect(3.14e0).to.be-between(3.0e0, 4.0e0);
  }

  it 'works across Int and Rat', {
    expect(2).to.be-between(1.5, 2.5);
  }

  it 'works with negative ranges', {
    expect(-3).to.be-between(-5, -1);
  }

  it 'works with zero bounds', {
    expect(0).to.be-between(-1, 1);
    expect(0).to.be-between(0, 0);
  }

  it 'fails on undefined actual', {
    my @captured = capture-failures {
      expect(Int).to.be-between(0, 10);
    };
    expect(@captured.elems).to.be(1);
  }

  it 'fails on non-Real actual', {
    my @captured = capture-failures {
      expect('abc').to.be-between(0, 10);
    };
    expect(@captured.elems).to.be(1);
  }
}

describe 'be-between with .inclusive (explicit)', {
  it 'passes when actual equals the lower bound', {
    expect(1).to.be-between(1, 10).inclusive;
  }

  it 'passes when actual equals the upper bound', {
    expect(10).to.be-between(1, 10).inclusive;
  }

  it 'passes when actual is strictly inside', {
    expect(5).to.be-between(1, 10).inclusive;
  }

  it 'fails when actual is below the lower bound', {
    my @captured = capture-failures {
      expect(0).to.be-between(1, 10).inclusive;
    };
    expect(@captured.elems).to.be(1);
  }
}

describe 'be-between with .exclusive', {
  it 'fails when actual equals the lower bound', {
    my @captured = capture-failures {
      expect(1).to.be-between(1, 10).exclusive;
    };
    expect(@captured.elems).to.be(1);
  }

  it 'fails when actual equals the upper bound', {
    my @captured = capture-failures {
      expect(10).to.be-between(1, 10).exclusive;
    };
    expect(@captured.elems).to.be(1);
  }

  it 'passes when actual is strictly inside', {
    expect(5).to.be-between(1, 10).exclusive;
  }

  it 'fails when actual is below the lower bound', {
    my @captured = capture-failures {
      expect(0).to.be-between(1, 10).exclusive;
    };
    expect(@captured.elems).to.be(1);
  }

  it 'fails when actual is above the upper bound', {
    my @captured = capture-failures {
      expect(11).to.be-between(1, 10).exclusive;
    };
    expect(@captured.elems).to.be(1);
  }
}

describe 'be-between modifier chaining clears prior failure', {
  it 'inclusive default fails on boundary, .exclusive keeps failure', {
    my @captured = capture-failures {
      expect(10).to.be-between(1, 10).exclusive;
    };
    expect(@captured.elems).to.be(1);
  }

  it 'inclusive default passes on boundary, .exclusive flips to failure', {
    my @captured = capture-failures {
      expect(10).to.be-between(1, 10);
    };
    expect(@captured.elems).to.be(0);
    my @captured2 = capture-failures {
      expect(10).to.be-between(1, 10).exclusive;
    };
    expect(@captured2.elems).to.be(1);
  }

  it 'exclusive failure clears when .inclusive is then chained', {
    my @captured = capture-failures {
      expect(10).to.be-between(1, 10).exclusive.inclusive;
    };
    expect(@captured.elems).to.be(0);
  }
}

describe 'be-between negation', {
  it 'passes when actual is below the inclusive lower bound', {
    expect(0).to.not.be-between(1, 10);
  }

  it 'passes when actual is above the inclusive upper bound', {
    expect(11).to.not.be-between(1, 10);
  }

  it 'fails when actual is within inclusive bounds', {
    my @captured = capture-failures {
      expect(5).to.not.be-between(1, 10);
    };
    expect(@captured.elems).to.be(1);
  }

  it 'fails when actual equals a boundary (inclusive default)', {
    my @captured = capture-failures {
      expect(1).to.not.be-between(1, 10);
    };
    expect(@captured.elems).to.be(1);
  }

  it 'passes when actual equals a boundary under .exclusive', {
    expect(1).to.not.be-between(1, 10).exclusive;
  }

  it 'records a negated failure message', {
    my @captured = capture-failures {
      expect(5).to.not.be-between(1, 10);
    };
    my $message = @captured[0].message;
    expect($message).to.be(
      'expected 5 not to be between 1 and 10 (inclusive)'
    );
  }

  it 'marks the failure as negated', {
    my @captured = capture-failures {
      expect(5).to.not.be-between(1, 10);
    };
    expect(@captured[0].negated).to.be-truthy;
  }
}

describe 'be-between failure messages', {
  it 'inclusive failure message names both bounds', {
    my @captured = capture-failures {
      expect(11).to.be-between(1, 10);
    };
    my $message = @captured[0].message;
    expect($message).to.be(
      'expected 11 to be between 1 and 10 (inclusive)'
    );
  }

  it 'exclusive failure message names both bounds', {
    my @captured = capture-failures {
      expect(10).to.be-between(1, 10).exclusive;
    };
    my $message = @captured[0].message;
    expect($message).to.be(
      'expected 10 to be between 1 and 10 (exclusive)'
    );
  }
}

describe 'be-between preserves Failure tooling fields', {
  it 'preserves Failure.given', {
    my @captured = capture-failures {
      expect(11).to.be-between(1, 10);
    };
    expect(@captured[0].given).to.be(11);
  }

  it 'preserves Failure.expected as a two-element list', {
    my @captured = capture-failures {
      expect(11).to.be-between(1, 10);
    };
    my $expected = @captured[0].expected;
    expect($expected.elems).to.be(2);
    expect($expected[0]).to.be(1);
    expect($expected[1]).to.be(10);
  }
}
