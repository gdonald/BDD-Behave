use BDD::Behave;

class IsExpectedWidget {
  has $.bar;
  method greet { "hello $!bar" }
}

describe 'is-expected with anonymous subject', {
  subject({ IsExpectedWidget.new(:bar(99)) });

  it 'is the subject value', {
    is-expected.to.be(IsExpectedWidget);
  }
}

describe 'is-expected with named subject', {
  subject(:widget, { IsExpectedWidget.new(:bar(7)) });

  it 'reads the named subject', {
    is-expected.to.be(IsExpectedWidget);
  }
}

describe 'is-expected memoization within an example', {
  my $hits = 0;
  subject({ ++$hits });

  it 'evaluates subject exactly once', {
    is-expected.to.be(1);
    is-expected.to.be(1);
    expect($hits).to.be(1);
  }
}

describe 'is-expected supports negation', {
  subject({ 'hello' });

  it 'negates correctly', {
    is-expected.not.to.be('goodbye');
  }
}

describe 'one-liner it { ... } with auto description', {
  subject({ 42 });

  it { is-expected.to.be(42) }
  it { is-expected.not.to.be(99) }
}

describe 'one-liner it { ... } without subject', {
  it { expect(1 + 1).to.be(2) }
  it { expect('abc').to.be('abc') }
}

describe 'one-liner it mixed with regular it', {
  subject({ 'value' });

  it 'still works as a regular example with description', {
    is-expected.to.be('value');
  }

  it { is-expected.to.be('value') }
}

