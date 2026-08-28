use BDD::Behave;
use BDD::Behave::Matcher::Boolean;
use BDD::Behave::Matcher::Core;
use BDD::Behave::Matcher::String;

# A matcher's description is what composed matchers and the `eventually` wrapper
# read to build their own, so each one is asked for it here.
describe 'the way a matcher describes itself', {
  it 'describes an equality matcher by the value it holds', {
    expect(EqMatcher.new(:expected(42)).description).to.eq('eq 42');
  }

  it 'describes an equality matcher holding a string', {
    expect(EqMatcher.new(:expected('a name')).description).to.eq('eq "a name"');
  }

  it 'describes a truthiness matcher', {
    expect(BeTruthyMatcher.new.description).to.eq('be truthy');
  }

  it 'describes a falsiness matcher', {
    expect(BeFalsyMatcher.new.description).to.eq('be falsy');
  }

  it 'describes a nil matcher', {
    expect(BeNilMatcher.new.description).to.eq('be nil');
  }

  it 'describes a pattern matcher by the pattern it holds', {
    expect(MatchMatcher.new(:expected(/'ready'/)).description).to.include('match');
  }
}
