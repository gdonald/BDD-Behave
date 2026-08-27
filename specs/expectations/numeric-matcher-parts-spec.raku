use BDD::Behave;
use BDD::Behave::Matcher::Numeric;

# The expectation builder reports these through `expect`, so the descriptions
# and negated messages each matcher carries are read here directly.
describe 'the way a numeric matcher describes itself', {
  it 'describes a lower bound that excludes the value', {
    expect(BeGreaterThanMatcher.new(:expected(3)).description).to.eq('be greater than 3');
  }

  it 'describes a lower bound that includes the value', {
    expect(BeGreaterThanOrEqualMatcher.new(:expected(3)).description)
      .to.eq('be greater than or equal to 3');
  }

  it 'describes an upper bound that excludes the value', {
    expect(BeLessThanMatcher.new(:expected(7)).description).to.eq('be less than 7');
  }

  it 'describes an upper bound that includes the value', {
    expect(BeLessThanOrEqualMatcher.new(:expected(7)).description)
      .to.eq('be less than or equal to 7');
  }

  it 'describes a range', {
    expect(BeBetweenMatcher.new(:min(1), :max(9)).description).to.eq('be between 1 and 9 (inclusive)');
  }

  it 'describes a tolerance', {
    expect(BeWithinMatcher.new(:delta(0.5), :expected(10)).description)
      .to.eq('be within 0.5 of 10');
  }
}

describe 'the way a numeric matcher reports a match that was not wanted', {
  it 'reports a lower bound that includes the value', {
    expect(BeGreaterThanOrEqualMatcher.new(:expected(3)).failure-message-negated(5))
      .to.eq('expected 5 not to be greater than or equal to 3');
  }

  it 'reports an upper bound that includes the value', {
    expect(BeLessThanOrEqualMatcher.new(:expected(7)).failure-message-negated(5))
      .to.eq('expected 5 not to be less than or equal to 7');
  }

  it 'reports a range', {
    expect(BeBetweenMatcher.new(:min(1), :max(9)).failure-message-negated(5))
      .to.eq('expected 5 not to be between 1 and 9 (inclusive)');
  }

  it 'reports a tolerance', {
    expect(BeWithinMatcher.new(:delta(0.5), :expected(10)).failure-message-negated(10))
      .to.eq('expected 10 not to be within 0.5 of 10');
  }
}

describe 'the value a numeric matcher expected', {
  it 'reports the bound of a lower bound', {
    expect(BeGreaterThanOrEqualMatcher.new(:expected(3)).expected-value).to.be(3);
  }

  it 'reports both ends of a range', {
    expect(BeBetweenMatcher.new(:min(1), :max(9)).expected-value.join(',')).to.eq('1,9');
  }

  it 'reports the centre of a tolerance', {
    expect(BeWithinMatcher.new(:delta(0.5), :expected(10)).expected-value).to.be(10);
  }
}
