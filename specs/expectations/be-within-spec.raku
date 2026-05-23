use BDD::Behave;
use BDD::Behave::Failures;

describe 'be-within matcher', {
  it 'passes when actual equals expected', {
    expect(5.0).to.be-within(0.1).of(5.0);
  }

  it 'passes when actual differs from expected by less than delta', {
    expect(5.05).to.be-within(0.1).of(5.0);
  }

  it 'passes when actual differs from expected by exactly delta', {
    expect(5.1).to.be-within(0.1).of(5.0);
  }

  it 'passes for negative differences within delta', {
    expect(4.95).to.be-within(0.1).of(5.0);
  }

  it 'fails when actual differs from expected by more than delta', {
    my @captured = capture-failures {
      expect(5.2).to.be-within(0.1).of(5.0);
    };
    expect(@captured.elems).to.be(1);
  }

  it 'fails when actual is below expected by more than delta', {
    my @captured = capture-failures {
      expect(4.8).to.be-within(0.1).of(5.0);
    };
    expect(@captured.elems).to.be(1);
  }

  it 'works with Int actual and Int expected', {
    expect(10).to.be-within(2).of(11);
  }

  it 'works with Num floating-point values', {
    expect(3.14e0).to.be-within(0.01e0).of(3.15e0);
  }

  it 'works across Int and Rat', {
    expect(2).to.be-within(0.5).of(2.25);
  }

  it 'works with negative values', {
    expect(-5.05).to.be-within(0.1).of(-5.0);
  }

  it 'works with zero expected', {
    expect(0.05).to.be-within(0.1).of(0);
  }

  it 'works with zero delta only when values are equal', {
    expect(5).to.be-within(0).of(5);
  }

  it 'fails with zero delta when values differ', {
    my @captured = capture-failures {
      expect(5.0001).to.be-within(0).of(5);
    };
    expect(@captured.elems).to.be(1);
  }
}

describe 'be-within with undefined / non-Real values', {
  it 'fails on undefined actual', {
    my @captured = capture-failures {
      expect(Int).to.be-within(0.1).of(5.0);
    };
    expect(@captured.elems).to.be(1);
  }

  it 'fails on non-Real actual', {
    my @captured = capture-failures {
      expect('abc').to.be-within(0.1).of(5.0);
    };
    expect(@captured.elems).to.be(1);
  }

  it 'fails on undefined expected', {
    my @captured = capture-failures {
      expect(5.0).to.be-within(0.1).of(Int);
    };
    expect(@captured.elems).to.be(1);
  }

  it 'fails on non-Real expected', {
    my @captured = capture-failures {
      expect(5.0).to.be-within(0.1).of('abc');
    };
    expect(@captured.elems).to.be(1);
  }
}

describe 'be-within negation', {
  it 'passes when actual is outside the delta range', {
    expect(5.2).to.not.be-within(0.1).of(5.0);
  }

  it 'fails when actual is within the delta range', {
    my @captured = capture-failures {
      expect(5.05).to.not.be-within(0.1).of(5.0);
    };
    expect(@captured.elems).to.be(1);
  }

  it 'fails when actual equals expected exactly', {
    my @captured = capture-failures {
      expect(5.0).to.not.be-within(0.1).of(5.0);
    };
    expect(@captured.elems).to.be(1);
  }

  it 'records a negated failure message', {
    my @captured = capture-failures {
      expect(5.05).to.not.be-within(0.1).of(5.0);
    };
    my $message = @captured[0].message;
    expect($message).to.be(
      'expected 5.05 not to be within 0.1 of 5.0'
    );
  }

  it 'marks the failure as negated', {
    my @captured = capture-failures {
      expect(5.05).to.not.be-within(0.1).of(5.0);
    };
    expect(@captured[0].negated).to.be-truthy;
  }
}

describe 'be-within failure messages', {
  it 'failure message names delta and expected', {
    my @captured = capture-failures {
      expect(5.2).to.be-within(0.1).of(5.0);
    };
    my $message = @captured[0].message;
    expect($message).to.be(
      'expected 5.2 to be within 0.1 of 5.0'
    );
  }
}

describe 'be-within preserves Failure tooling fields', {
  it 'preserves Failure.given', {
    my @captured = capture-failures {
      expect(5.2).to.be-within(0.1).of(5.0);
    };
    expect(@captured[0].given).to.be(5.2);
  }

  it 'preserves Failure.expected as the expected target value', {
    my @captured = capture-failures {
      expect(5.2).to.be-within(0.1).of(5.0);
    };
    expect(@captured[0].expected).to.be(5.0);
  }
}
