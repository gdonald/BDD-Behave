use BDD::Behave;
use BDD::Behave::Failures;

my class X::Throw::Demo is Exception {
  has $.code;
  method message { "throw-demo failure: code={$!code}" }
}

my class X::Throw::Sub is X::Throw::Demo { }

describe 'throw alias basics', {
  it 'passes when the block raises with die', {
    expect({ die "boom" }).to.throw;
  }

  it 'passes when the block throws a typed exception', {
    expect({ X::AdHoc.new(payload => 'oops').throw }).to.throw;
  }

  it 'fails when the block does not raise', {
    Failures.list = ();
    expect({ 1 + 1 }).to.throw;
    my $count = Failures.list.elems;
    Failures.list = ();

    expect($count).to.be(1);
  }

  it 'records the same failure wording as raise-error', {
    Failures.list = ();
    expect({ 42 }).to.throw;
    my $message = Failures.list[0].message;
    Failures.list = ();

    expect($message).to.be(
      'expected block to raise an error, but none was raised'
    );
  }
}

describe 'throw alias with non-Callable actuals', {
  it 'fails when given an Int', {
    Failures.list = ();
    expect(42).to.throw;
    my $count = Failures.list.elems;
    Failures.list = ();

    expect($count).to.be(1);
  }
}

describe 'throw alias negation', {
  it 'passes when the block does not raise', {
    expect({ 1 + 1 }).to.not.throw;
  }

  it 'fails when the block raises under negation', {
    Failures.list = ();
    expect({ die "boom" }).to.not.throw;
    my $count = Failures.list.elems;
    Failures.list = ();

    expect($count).to.be(1);
  }
}

describe 'throw alias with an exception type', {
  it 'passes when the raised exception matches the type', {
    expect({ X::Throw::Demo.new(:code(7)).throw })
      .to.throw(X::Throw::Demo);
  }

  it 'passes for a subclass of the expected type', {
    expect({ X::Throw::Sub.new(:code(9)).throw })
      .to.throw(X::Throw::Demo);
  }

  it 'fails when a different exception type is raised', {
    Failures.list = ();
    expect({ die "boom" }).to.throw(X::Throw::Demo);
    my $count = Failures.list.elems;
    Failures.list = ();

    expect($count).to.be(1);
  }
}

describe 'throw alias with type and message regex', {
  it 'passes when type and message both match', {
    expect({ X::Throw::Demo.new(:code(11)).throw })
      .to.throw(X::Throw::Demo, /'code=11'/);
  }

  it 'fails when the message does not match', {
    Failures.list = ();
    expect({ X::Throw::Demo.new(:code(11)).throw })
      .to.throw(X::Throw::Demo, /'code=99'/);
    my $count = Failures.list.elems;
    Failures.list = ();

    expect($count).to.be(1);
  }
}

describe 'throw alias with message-only regex', {
  it 'passes for any exception whose message matches', {
    expect({ die "alpha bravo" }).to.throw(/'bravo'/);
  }

  it 'fails when the regex does not match', {
    Failures.list = ();
    expect({ die "alpha" }).to.throw(/'bravo'/);
    my $count = Failures.list.elems;
    Failures.list = ();

    expect($count).to.be(1);
  }
}

describe 'throw alias chained with with-message', {
  it 'passes when the Str message matches exactly', {
    expect({ die "boom" }).to.throw.with-message('boom');
  }

  it 'passes when the Regex message matches', {
    expect({ die "alpha bravo" }).to.throw.with-message(/'bravo'/);
  }

  it 'fails when the Str message does not match', {
    Failures.list = ();
    expect({ die "boom" }).to.throw.with-message('bang');
    my $count = Failures.list.elems;
    Failures.list = ();

    expect($count).to.be(1);
  }
}
