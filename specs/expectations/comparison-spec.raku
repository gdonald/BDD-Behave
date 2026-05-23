use BDD::Behave;
use BDD::Behave::Failures;

describe 'be-greater-than matcher', {
  it 'passes when actual is greater than expected', {
    expect(5).to.be-greater-than(3);
  }

  it 'fails when actual equals expected', {
    my @captured = capture-failures {
      expect(5).to.be-greater-than(5);
    };
    expect(@captured.elems).to.be(1);
  }

  it 'fails when actual is less than expected', {
    my @captured = capture-failures {
      expect(2).to.be-greater-than(5);
    };
    expect(@captured.elems).to.be(1);
  }

  it 'works with Rat values', {
    expect(1.5).to.be-greater-than(1.4);
  }

  it 'works with Num values', {
    expect(3.14e0).to.be-greater-than(3.0e0);
  }

  it 'compares Int against Rat', {
    expect(5).to.be-greater-than(4.99);
  }

  it 'compares negative numbers', {
    expect(-1).to.be-greater-than(-5);
  }

  it 'works with zero', {
    expect(1).to.be-greater-than(0);
    expect(0).to.not.be-greater-than(0);
  }

  it 'fails on undefined actual', {
    my @captured = capture-failures {
      expect(Int).to.be-greater-than(0);
    };
    expect(@captured.elems).to.be(1);
  }

  it 'fails on non-Real actual', {
    my @captured = capture-failures {
      expect('abc').to.be-greater-than(0);
    };
    expect(@captured.elems).to.be(1);
  }

  it 'negation passes when actual is not greater', {
    expect(3).to.not.be-greater-than(5);
  }

  it 'records a matcher-supplied failure message', {
    my @captured = capture-failures {
      expect(2).to.be-greater-than(5);
    };
    my $message = @captured[0].message;
    expect($message).to.be('expected 2 to be greater than 5');
  }

  it 'records a negated failure message', {
    my @captured = capture-failures {
      expect(7).to.not.be-greater-than(5);
    };
    my $message = @captured[0].message;
    expect($message).to.be('expected 7 not to be greater than 5');
  }

  it 'has a be-gt alias', {
    expect(5).to.be-gt(3);
    expect(3).to.not.be-gt(5);
  }

  it 'preserves Failure.given and Failure.expected for tooling', {
    my @captured = capture-failures {
      expect(2).to.be-greater-than(5);
    };
    expect(@captured[0].given).to.be(2);
    expect(@captured[0].expected).to.be(5);
  }
}

describe 'be-greater-than-or-equal-to matcher', {
  it 'passes when actual is greater than expected', {
    expect(5).to.be-greater-than-or-equal-to(3);
  }

  it 'passes when actual equals expected', {
    expect(5).to.be-greater-than-or-equal-to(5);
  }

  it 'fails when actual is less than expected', {
    my @captured = capture-failures {
      expect(2).to.be-greater-than-or-equal-to(5);
    };
    expect(@captured.elems).to.be(1);
  }

  it 'works with Rat values', {
    expect(1.5).to.be-greater-than-or-equal-to(1.5);
  }

  it 'compares negative numbers', {
    expect(-1).to.be-greater-than-or-equal-to(-1);
  }

  it 'fails on undefined actual', {
    my @captured = capture-failures {
      expect(Int).to.be-greater-than-or-equal-to(0);
    };
    expect(@captured.elems).to.be(1);
  }

  it 'negation passes when actual is less', {
    expect(3).to.not.be-greater-than-or-equal-to(5);
  }

  it 'records a matcher-supplied failure message', {
    my @captured = capture-failures {
      expect(2).to.be-greater-than-or-equal-to(5);
    };
    my $message = @captured[0].message;
    expect($message).to.be('expected 2 to be greater than or equal to 5');
  }

  it 'has a be-gte alias', {
    expect(5).to.be-gte(5);
    expect(3).to.not.be-gte(5);
  }

  it 'preserves Failure.given and Failure.expected for tooling', {
    my @captured = capture-failures {
      expect(4).to.be-greater-than-or-equal-to(5);
    };
    expect(@captured[0].given).to.be(4);
    expect(@captured[0].expected).to.be(5);
  }
}

describe 'be-less-than matcher', {
  it 'passes when actual is less than expected', {
    expect(3).to.be-less-than(5);
  }

  it 'fails when actual equals expected', {
    my @captured = capture-failures {
      expect(5).to.be-less-than(5);
    };
    expect(@captured.elems).to.be(1);
  }

  it 'fails when actual is greater than expected', {
    my @captured = capture-failures {
      expect(7).to.be-less-than(5);
    };
    expect(@captured.elems).to.be(1);
  }

  it 'works with Rat values', {
    expect(1.4).to.be-less-than(1.5);
  }

  it 'compares Int against Rat', {
    expect(4).to.be-less-than(4.01);
  }

  it 'compares negative numbers', {
    expect(-5).to.be-less-than(-1);
  }

  it 'works with zero', {
    expect(-1).to.be-less-than(0);
    expect(0).to.not.be-less-than(0);
  }

  it 'fails on undefined actual', {
    my @captured = capture-failures {
      expect(Int).to.be-less-than(10);
    };
    expect(@captured.elems).to.be(1);
  }

  it 'fails on non-Real actual', {
    my @captured = capture-failures {
      expect('abc').to.be-less-than(10);
    };
    expect(@captured.elems).to.be(1);
  }

  it 'negation passes when actual is not less', {
    expect(7).to.not.be-less-than(5);
  }

  it 'records a matcher-supplied failure message', {
    my @captured = capture-failures {
      expect(7).to.be-less-than(5);
    };
    my $message = @captured[0].message;
    expect($message).to.be('expected 7 to be less than 5');
  }

  it 'records a negated failure message', {
    my @captured = capture-failures {
      expect(2).to.not.be-less-than(5);
    };
    my $message = @captured[0].message;
    expect($message).to.be('expected 2 not to be less than 5');
  }

  it 'has a be-lt alias', {
    expect(3).to.be-lt(5);
    expect(7).to.not.be-lt(5);
  }

  it 'preserves Failure.given and Failure.expected for tooling', {
    my @captured = capture-failures {
      expect(7).to.be-less-than(5);
    };
    expect(@captured[0].given).to.be(7);
    expect(@captured[0].expected).to.be(5);
  }
}

describe 'be-less-than-or-equal-to matcher', {
  it 'passes when actual is less than expected', {
    expect(3).to.be-less-than-or-equal-to(5);
  }

  it 'passes when actual equals expected', {
    expect(5).to.be-less-than-or-equal-to(5);
  }

  it 'fails when actual is greater than expected', {
    my @captured = capture-failures {
      expect(7).to.be-less-than-or-equal-to(5);
    };
    expect(@captured.elems).to.be(1);
  }

  it 'works with Rat values', {
    expect(1.5).to.be-less-than-or-equal-to(1.5);
  }

  it 'compares negative numbers', {
    expect(-1).to.be-less-than-or-equal-to(-1);
  }

  it 'fails on undefined actual', {
    my @captured = capture-failures {
      expect(Int).to.be-less-than-or-equal-to(10);
    };
    expect(@captured.elems).to.be(1);
  }

  it 'negation passes when actual is greater', {
    expect(7).to.not.be-less-than-or-equal-to(5);
  }

  it 'records a matcher-supplied failure message', {
    my @captured = capture-failures {
      expect(7).to.be-less-than-or-equal-to(5);
    };
    my $message = @captured[0].message;
    expect($message).to.be('expected 7 to be less than or equal to 5');
  }

  it 'has a be-lte alias', {
    expect(5).to.be-lte(5);
    expect(7).to.not.be-lte(5);
  }

  it 'preserves Failure.given and Failure.expected for tooling', {
    my @captured = capture-failures {
      expect(7).to.be-less-than-or-equal-to(5);
    };
    expect(@captured[0].given).to.be(7);
    expect(@captured[0].expected).to.be(5);
  }
}
