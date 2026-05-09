use BDD::Behave;

class SpyGreeter {
  method hello($name) { "hello, $name" }
  method bye          { 'bye'         }
}

describe 'spy() with no arguments', {
  it 'returns an anonymous double that records calls', {
    my $s = spy();
    $s.poke('hi');
    expect($s.received('poke')).to.be(True);
    expect($s.call-count('poke')).to.be(1);
  }
}

describe 'spy with a name', {
  it 'behaves like a permissive double', {
    my $s = spy('Logger');
    $s.warn('careful');
    expect($s.received('warn')).to.be(True);
    expect($s.warn).to.be(Any);
  }
}

describe 'spy with stubs', {
  it 'returns the stubbed values for known methods', {
    my $s = spy('User', name => 'alice');
    expect($s.name).to.be('alice');
    expect($s.email).to.be(Any);
  }
}

describe 'spy on a real instance', {
  it 'preserves the real implementation while recording calls', {
    my $g = SpyGreeter.new;
    spy($g);

    expect($g.hello('alice')).to.be('hello, alice');
    expect($g.bye).to.be('bye');

    expect($g).to.have-received('hello');
    expect($g).to.have-received('bye');
  }

  it 'leaves sibling instances unaffected', {
    my $g     = SpyGreeter.new;
    my $other = SpyGreeter.new;
    spy($g);

    $other.hello('bob');

    expect($g).not.to.have-received('hello');
  }
}
