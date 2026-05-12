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
    Failures.list = ();
    expect(5.2).to.be-within(0.1).of(5.0);
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }

  it 'fails when actual is below expected by more than delta', {
    Failures.list = ();
    expect(4.8).to.be-within(0.1).of(5.0);
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
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
    Failures.list = ();
    expect(5.0001).to.be-within(0).of(5);
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }
}

describe 'be-within with undefined / non-Real values', {
  it 'fails on undefined actual', {
    Failures.list = ();
    expect(Int).to.be-within(0.1).of(5.0);
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }

  it 'fails on non-Real actual', {
    Failures.list = ();
    expect('abc').to.be-within(0.1).of(5.0);
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }

  it 'fails on undefined expected', {
    Failures.list = ();
    expect(5.0).to.be-within(0.1).of(Int);
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }

  it 'fails on non-Real expected', {
    Failures.list = ();
    expect(5.0).to.be-within(0.1).of('abc');
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }
}

describe 'be-within negation', {
  it 'passes when actual is outside the delta range', {
    expect(5.2).to.not.be-within(0.1).of(5.0);
  }

  it 'fails when actual is within the delta range', {
    Failures.list = ();
    expect(5.05).to.not.be-within(0.1).of(5.0);
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }

  it 'fails when actual equals expected exactly', {
    Failures.list = ();
    expect(5.0).to.not.be-within(0.1).of(5.0);
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }

  it 'records a negated failure message', {
    Failures.list = ();
    expect(5.05).to.not.be-within(0.1).of(5.0);
    my $message = Failures.list[0].message;
    Failures.list = ();
    expect($message).to.be(
      'expected 5.05 not to be within 0.1 of 5.0'
    );
  }

  it 'marks the failure as negated', {
    Failures.list = ();
    expect(5.05).to.not.be-within(0.1).of(5.0);
    expect(Failures.list[0].negated ?? 1 !! 0).to.be(1);
    Failures.list = ();
  }
}

describe 'be-within failure messages', {
  it 'failure message names delta and expected', {
    Failures.list = ();
    expect(5.2).to.be-within(0.1).of(5.0);
    my $message = Failures.list[0].message;
    Failures.list = ();
    expect($message).to.be(
      'expected 5.2 to be within 0.1 of 5.0'
    );
  }
}

describe 'be-within preserves Failure tooling fields', {
  it 'preserves Failure.given', {
    Failures.list = ();
    expect(5.2).to.be-within(0.1).of(5.0);
    expect(Failures.list[0].given).to.be(5.2);
    Failures.list = ();
  }

  it 'preserves Failure.expected as the expected target value', {
    Failures.list = ();
    expect(5.2).to.be-within(0.1).of(5.0);
    expect(Failures.list[0].expected).to.be(5.0);
    Failures.list = ();
  }
}
