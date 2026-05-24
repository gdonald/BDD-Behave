use BDD::Behave;

my class HRGreeter {
  method hello($name)        { "hello, $name"        }
  method farewell(:$lang!)   { "$lang farewell"      }
  method log($level, *@msg)  { "$level: {@msg.join(' ')}" }
}

describe 'expect(double).to.have-received(method)', {
  it 'passes when the method was called at least once', {
    my $log = double('Logger');
    $log.info('starting');
    expect($log).to.have-received('info');
  }
}

describe 'expect(real-obj).to.have-received(method)', {
  it 'works after allow().and-call-original', {
    my $g = HRGreeter.new;
    allow($g).to.receive('hello').and-call-original;
    $g.hello('alice');
    expect($g).to.have-received('hello');
  }

  it 'works for plain allow() without .and-call-original', {
    my $g = HRGreeter.new;
    allow($g).to.receive('hello').and-return('STUB');
    $g.hello('alice');
    expect($g).to.have-received('hello');
  }
}

describe 'expect(...).not.to.have-received(...)', {
  it 'passes when the method was not called', {
    my $g = HRGreeter.new;
    allow($g).to.receive('hello').and-call-original;
    expect($g).not.to.have-received('hello');
  }
}

describe '.with(positional args)', {
  it 'passes when a call matches the args', {
    my $log = double('Logger');
    $log.info('starting');
    $log.info('done');
    expect($log).to.have-received('info').with('starting');
  }
}

describe '.with(named args)', {
  it 'passes when a call matches the named args', {
    my $g = HRGreeter.new;
    allow($g).to.receive('farewell').and-return('bye');
    $g.farewell(:lang<en>);
    expect($g).to.have-received('farewell').with(:lang<en>);
  }
}

describe '.times(n) / .once / .twice', {
  it 'passes when call count matches exactly', {
    my $log = double('Logger');
    $log.info('a');
    $log.info('b');
    expect($log).to.have-received('info').twice;
  }

  it '.exactly(n) is an alias for .times(n)', {
    my $log = double('Logger');
    $log.info('a');
    $log.info('b');
    $log.info('c');
    expect($log).to.have-received('info').exactly(3);
  }

  it '.once passes for a single call', {
    my $log = double('Logger');
    $log.info('one');
    expect($log).to.have-received('info').once;
  }
}

describe '.at-least / .at-most', {
  it 'at-least passes when call count >= n', {
    my $log = double('Logger');
    $log.info('a');
    $log.info('b');
    $log.info('c');
    expect($log).to.have-received('info').at-least(2);
  }

  it 'at-most passes when call count <= n', {
    my $log = double('Logger');
    $log.info('a');
    expect($log).to.have-received('info').at-most(3);
  }
}

describe '.with combined with .times', {
  it 'counts only matching calls', {
    my $log = double('Logger');
    $log.info('a');
    $log.info('a');
    $log.info('b');
    expect($log).to.have-received('info').with('a').twice;
  }
}

describe 'argument matchers', {
  it 'anything matches any value', {
    my $log = double('Logger');
    $log.info('hello', 42);
    expect($log).to.have-received('info').with(anything, anything);
  }

  it 'instance-of matches by type', {
    my $log = double('Logger');
    $log.info('hello', 42);
    expect($log).to.have-received('info').with(instance-of(Str), instance-of(Int));
  }

  it 'hash-including matches hashes with the listed pairs', {
    my $log = double('Logger');
    $log.info({ user => 'alice', region => 'us', extra => 'x' });
    expect($log).to.have-received('info').with(hash-including(user => 'alice', region => 'us'));
  }

  it 'array-including matches arrays containing the listed items', {
    my $log = double('Logger');
    $log.info([1, 2, 3, 4, 5]);
    expect($log).to.have-received('info').with(array-including(2, 4));
  }
}
