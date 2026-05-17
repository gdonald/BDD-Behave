use BDD::Behave;
use BDD::Behave::Formatter;
use BDD::Behave::Formatter::Default;
use BDD::Behave::Formatter::Registry;

class CustomTestFormatter does BDD::Behave::Formatter {
  method name(--> Str) { 'custom-test' }
}

class NotAFormatter { }

describe 'BDD::Behave::Formatter::Registry', {
  before-each {
    BDD::Behave::Formatter::Registry.reset;
  }

  after-each {
    BDD::Behave::Formatter::Registry.reset;
  }

  it 'registers "default" out of the box', {
    expect(BDD::Behave::Formatter::Registry.registered('default')).to.be-truthy;
  }

  it 'exposes registered names in sorted order', {
    BDD::Behave::Formatter::Registry.register('custom-test', CustomTestFormatter);
    expect(BDD::Behave::Formatter::Registry.names).to.eq(<custom-test default>.List);
  }

  it 'looks up a registered formatter class by name', {
    expect(BDD::Behave::Formatter::Registry.lookup('default'))
      .to.be(BDD::Behave::Formatter::Default);
  }

  it 'creates a formatter instance from a registered name', {
    my $f = BDD::Behave::Formatter::Registry.create('default');
    expect($f).to.be-a(BDD::Behave::Formatter::Default);
  }

  it 'forwards args to .new when creating an instance', {
    BDD::Behave::Formatter::Registry.register('custom-test', CustomTestFormatter);
    my $f = BDD::Behave::Formatter::Registry.create('custom-test');
    expect($f).to.be-a(CustomTestFormatter);
  }

  it 'returns False for unregistered formatter names', {
    expect(BDD::Behave::Formatter::Registry.registered('nope')).to.be-falsy;
  }

  it 'raises a helpful error when looking up an unknown name', {
    expect({ BDD::Behave::Formatter::Registry.lookup('nope') })
      .to.raise-error(/'Unknown formatter'/);
  }

  it 'rejects duplicate registrations under the same name', {
    BDD::Behave::Formatter::Registry.register('custom-test', CustomTestFormatter);
    expect({
      BDD::Behave::Formatter::Registry.register('custom-test', CustomTestFormatter);
    }).to.raise-error(/'already been registered'/);
  }

  it 'rejects registering a class that does not compose the role', {
    expect({
      BDD::Behave::Formatter::Registry.register('bad', NotAFormatter);
    }).to.raise-error(/'must compose'/);
  }

  it 'reset restores only the built-in default formatter', {
    BDD::Behave::Formatter::Registry.register('custom-test', CustomTestFormatter);
    BDD::Behave::Formatter::Registry.reset;
    expect(BDD::Behave::Formatter::Registry.names).to.eq(<default>.List);
    expect(BDD::Behave::Formatter::Registry.registered('custom-test')).to.be-falsy;
  }
}
