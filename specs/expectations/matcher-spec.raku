use BDD::Behave;
use BDD::Behave::Matcher;
use BDD::Behave::Failures;

class EvenMatcher does Matcher {
  method matches($actual --> Bool) { ?($actual %% 2) }
  method failure-message($actual --> Str) {
    "expected $actual to be even";
  }
  method failure-message-negated($actual --> Str) {
    "expected $actual not to be even";
  }
  method expected-value(--> Mu) { 'an even number' }
}

class TruthyMatcher does Matcher {
  method matches($actual --> Bool) { ?$actual }
  method failure-message($actual --> Str) { "expected truthy, got " ~ $actual.raku }
  method failure-message-negated($actual --> Str) { "expected falsy, got " ~ $actual.raku }
}

describe 'BeMatcher (built-in smartmatch wrapper)', {
  it 'matches equal values', {
    expect(BeMatcher.new(:expected(42)).matches(42) ?? 1 !! 0).to.be(1);
  }

  it 'rejects unequal values', {
    expect(BeMatcher.new(:expected(42)).matches(41) ?? 1 !! 0).to.be(0);
  }

  it 'preserves smartmatch semantics for types', {
    expect(BeMatcher.new(:expected(Int)).matches(7) ?? 1 !! 0).to.be(1);
  }

  it 'preserves smartmatch semantics for regex', {
    expect(BeMatcher.new(:expected(/hell/)).matches('hello') ?? 1 !! 0).to.be(1);
  }

  it 'preserves smartmatch semantics for ranges', {
    expect(BeMatcher.new(:expected(1..10)).matches(5) ?? 1 !! 0).to.be(1);
  }

  it 'preserves smartmatch semantics for junctions', {
    expect(BeMatcher.new(:expected(any(1, 2, 3))).matches(2) ?? 1 !! 0).to.be(1);
  }
}

describe 'custom Matcher plugged into expect.to.be', {
  it 'passes when matches returns True', {
    expect(4).to.be(EvenMatcher.new);
  }

  it 'fails with matcher-supplied message when matches returns False', {
    Failures.list = ();
    expect(5).to.be(EvenMatcher.new);
    expect(Failures.list.elems).to.be(1);
    expect(Failures.list[0].message).to.be('expected 5 to be even');
    expect(Failures.list[0].given).to.be(5);
    expect(Failures.list[0].expected).to.be('an even number');
    Failures.list = ();
  }

  it 'flips through .not and uses failure-message-negated', {
    expect(0).to.not.be(TruthyMatcher.new);
  }

  it 'records the negated message when .not fails', {
    Failures.list = ();
    expect(1).to.not.be(TruthyMatcher.new);
    expect(Failures.list.elems).to.be(1);
    expect(Failures.list[0].message).to.be('expected falsy, got 1');
    expect(Failures.list[0].negated ?? 1 !! 0).to.be(1);
    Failures.list = ();
  }
}

describe 'BeMatcher path keeps structured given/expected rendering', {
  it 'leaves Failure.message undefined so Failures.say falls back to Expected:/to be:', {
    Failures.list = ();
    expect(42).to.be(41);
    expect(Failures.list.elems).to.be(1);
    expect(Failures.list[0].message.defined ?? 1 !! 0).to.be(0);
    expect(Failures.list[0].given).to.be(42);
    expect(Failures.list[0].expected).to.be(41);
    Failures.list = ();
  }
}
