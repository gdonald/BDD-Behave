use BDD::Behave;
use BDD::Behave::Failures;
use BDD::Behave::Matcher;
use BDD::Behave::Matcher::Core;
use BDD::Behave::Matcher::Collection;

class PositiveMatcher does Matcher {
  method matches($actual --> Bool) { ?($actual.defined && $actual > 0) }
  method failure-message($actual --> Str) {
    "expected $actual to be positive";
  }
  method failure-message-negated($actual --> Str) {
    "expected $actual not to be positive";
  }
  method description(--> Str) { 'be positive' }
}

describe 'all matcher with plain values (smartmatch)', {
  it 'passes when every element equals the value', {
    expect([1, 1, 1]).to.all(1);
  }

  it 'passes when every element matches a type', {
    expect([1, 2, 3]).to.all(Int);
  }

  it 'passes when every element matches a range', {
    expect([1, 5, 10]).to.all(1..10);
  }

  it 'passes when every element matches a junction', {
    expect([1, 2, 3]).to.all(any(1, 2, 3));
  }

  it 'passes when every element matches a regex', {
    expect(['foo', 'food', 'football']).to.all(/^foo/);
  }

  it 'fails when one element does not match', {
    Failures.list = ();
    expect([1, 2, 1]).to.all(1);
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }

  it 'fails when no element matches', {
    Failures.list = ();
    expect([1, 2, 3]).to.all(99);
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }
}

describe 'all matcher with custom matcher instances', {
  it 'delegates to the inner matcher for each element', {
    expect([1, 2, 3]).to.all(PositiveMatcher.new);
  }

  it 'fails when one element fails the inner matcher', {
    Failures.list = ();
    expect([1, -2, 3]).to.all(PositiveMatcher.new);
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }

  it 'composes with the BeMatcher description', {
    Failures.list = ();
    expect([1, 2, 1]).to.all(1);
    my $message = Failures.list[0].message;
    Failures.list = ();
    expect($message.contains('to all be 1')).to.be-truthy;
  }

  it 'reports which element failed in the failure message', {
    Failures.list = ();
    expect([1, 2, 1]).to.all(1);
    my $message = Failures.list[0].message;
    Failures.list = ();
    expect($message.contains('element at index 1')).to.be-truthy;
    expect($message.contains('did not match')).to.be-truthy;
  }
}

describe 'all matcher with built-in matchers', {
  it 'composes with start-with via custom matchers', {
    expect([[1, 2], [1, 3], [1, 4]]).to.all(StartWithMatcher.new(:expected([1])));
  }

  it 'composes with include via custom matchers on strings', {
    expect(['hello', 'shell', 'help']).to.all(IncludeMatcher.new(:expected(['hel'])));
  }

  it 'fails when one element fails the composed matcher', {
    Failures.list = ();
    expect([[1, 2], [2, 3], [1, 4]]).to.all(StartWithMatcher.new(:expected([1])));
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }
}

describe 'all matcher on Lists and Hashes', {
  it 'works on Lists', {
    expect((1, 2, 3)).to.all(Int);
  }

  it 'iterates a Hash as Pairs', {
    expect({ a => 1, b => 1 }).to.all(:a(1) | :b(1));
  }
}

describe 'all matcher edge cases', {
  it 'passes vacuously on an empty array', {
    expect([]).to.all(1);
  }

  it 'passes vacuously on an empty list', {
    expect(()).to.all(Int);
  }

  it 'fails on undefined actual', {
    Failures.list = ();
    expect(Any).to.all(1);
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }

  it 'fails on non-iterable actual', {
    Failures.list = ();
    expect(42).to.all(1);
    expect(Failures.list.elems).to.be(1);
    Failures.list = ();
  }

  it 'records a collection-shape failure message on non-collection actual', {
    Failures.list = ();
    expect(42).to.all(1);
    my $message = Failures.list[0].message;
    Failures.list = ();
    expect($message.contains('to be a collection')).to.be-truthy;
  }
}

describe 'all matcher negation', {
  it 'negation passes when at least one element does not match', {
    expect([1, 2, 3]).to.not.all(1);
  }

  it 'negation fails when every element matches', {
    Failures.list = ();
    expect([1, 1, 1]).to.not.all(1);
    my $count = Failures.list.elems;
    my $message = Failures.list[0].message;
    my $negated = Failures.list[0].negated;
    Failures.list = ();
    expect($count).to.be(1);
    expect($message).to.be('expected $[1, 1, 1] not to all be 1');
    expect($negated).to.be-truthy;
  }
}

describe 'all matcher preserves Failure metadata', {
  it 'sets Failure.given to the actual collection', {
    Failures.list = ();
    expect([1, 2, 3]).to.all(0);
    expect(Failures.list[0].given).to.be([1, 2, 3]);
    Failures.list = ();
  }

  it 'sets Failure.expected to the inner matcher', {
    Failures.list = ();
    expect([1, 2, 3]).to.all(0);
    expect(Failures.list[0].expected ~~ Matcher).to.be-truthy;
    Failures.list = ();
  }
}
