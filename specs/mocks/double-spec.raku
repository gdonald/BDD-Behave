use BDD::Behave;

class Greeter {
  method hello($name) { "hello, $name" }
  method bye          { 'bye'         }
}

describe 'ad-hoc doubles', {
  it 'returns the value passed for each stubbed method', {
    my $user = double('User', name => 'alice', age => 30);

    expect($user.name).to.be('alice');
    expect($user.age).to.be(30);
  }

  it 'returns an undefined value for methods that have no stub', {
    my $user = double('User');

    expect($user.email).to.be(Any);
  }

  it 'records every method invocation in dispatch order', {
    my $log = double('Logger');
    $log.info('starting');
    $log.warn('careful');
    $log.info('done');

    expect($log.calls.elems).to.be(3);
    expect($log.call-count('info')).to.be(2);
    expect($log.call-count('warn')).to.be(1);
    expect($log.received('info')).to.be(True);
    expect($log.call-count('error')).to.be(0);
  }

  it 'invokes Callable stubs with the call arguments', {
    my $upper = double('Upper', shout => -> $s { $s.uc });

    expect($upper.shout('hi')).to.be('HI');
  }

  it 'lets you add stubs after creation with add-stub', {
    my $cfg = double('Config');
    $cfg.add-stub(theme => 'dark', font => 'mono');

    expect($cfg.theme).to.be('dark');
    expect($cfg.font).to.be('mono');
  }

  it 'clears call history with reset() while keeping stubs', {
    my $cache = double('Cache', get => 'hit');
    $cache.get;
    $cache.get;
    expect($cache.call-count('get')).to.be(2);

    $cache.reset;
    expect($cache.call-count('get')).to.be(0);
    expect($cache.get).to.be('hit');
  }
}

describe 'class-based doubles', {
  it 'records the class and uses its name as the double name', {
    my $g = double(Greeter, hello => 'hi there');

    expect($g.double-class === Greeter).to.be(True);
    expect($g.double-name).to.be('Greeter');
  }

  it 'returns the stub for a method that exists on the class', {
    my $g = double(Greeter, hello => 'mocked');

    expect($g.hello('whoever')).to.be('mocked');
  }
}
