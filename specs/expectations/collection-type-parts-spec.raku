use BDD::Behave;
need BDD::Behave::Benchmark::Format;
use BDD::Behave::Matcher::Collection;
use BDD::Behave::Matcher::Core;
use BDD::Behave::Matcher::Type;

my class Ledger {
  has Int $.balance = 0;
  method deposit($amount) { $amount }
}

# `expect` reports these through the builder, so the description each matcher
# carries is read here directly.
describe 'the way a collection matcher describes itself', {
  it 'describes the items a collection must hold', {
    expect(IncludeMatcher.new(:expected([1, 2])).description).to.eq('include 1, 2');
  }

  it 'describes the exact items a collection must hold', {
    expect(ContainExactlyMatcher.new(:expected([1, 2])).description)
      .to.eq('contain exactly 1, 2');
  }

  it 'describes the items a collection must start with', {
    expect(StartWithMatcher.new(:expected([1])).description).to.eq('start with 1');
  }

  it 'describes the items a collection must end with', {
    expect(EndWithMatcher.new(:expected([3])).description).to.eq('end with 3');
  }

  it 'describes a matcher every item must satisfy', {
    expect(AllMatcher.new(:inner(EqMatcher.new(:expected(1)))).description).to.eq('all eq 1');
  }
}

describe 'the way a type matcher describes itself', {
  it 'describes the type a value must be', {
    expect(BeAMatcher.new(:type(Str)).description).to.eq('be a Str');
  }

  it 'describes the type a value must be an instance of', {
    expect(BeAnInstanceOfMatcher.new(:type(Str)).description)
      .to.eq('be an instance of Str');
  }

  it 'describes the methods a value must answer', {
    expect(RespondToMatcher.new(:expected(['deposit'])).description)
      .to.include('respond to');
  }

  it 'describes the attributes a value must carry', {
    expect(HaveAttributesMatcher.new(:expected({ balance => 0 })).description)
      .to.include('have attributes');
  }
}

describe 'asking a collection matcher about something that is not a collection', {
  it 'does not match a plain number', {
    expect(IncludeMatcher.new(:expected([1])).matches(42)).to.be-falsy;
  }

  it 'does not match a type object', {
    expect(IncludeMatcher.new(:expected([1])).matches(Int)).to.be-falsy;
  }

  it 'matches a list holding the items', {
    expect(IncludeMatcher.new(:expected([1])).matches([1, 2])).to.be-truthy;
  }

  it 'matches a hash holding the pairs', {
    expect(IncludeMatcher.new(:expected([:size(3)])).matches({ :size(3) })).to.be-truthy;
  }
}

describe 'writing a benchmark value as json', {
  it 'writes a number', {
    expect(BDD::Behave::Benchmark::Format::to-json(42)).to.eq('42');
  }

  it 'writes a string', {
    expect(BDD::Behave::Benchmark::Format::to-json('a name')).to.eq('"a name"');
  }

  it 'writes a list', {
    expect(BDD::Behave::Benchmark::Format::to-json([1, 2])).to.eq('[1,2]');
  }

  it 'writes a map', {
    expect(BDD::Behave::Benchmark::Format::to-json({ :size(3) })).to.eq('{"size":3}');
  }

  it 'writes nothing at all as null', {
    expect(BDD::Behave::Benchmark::Format::to-json(Nil)).to.eq('null');
  }

  it 'writes anything else through its string form', {
    expect(BDD::Behave::Benchmark::Format::to-json(Version.new('1.2.3'))).to.eq('"1.2.3"');
  }
}
