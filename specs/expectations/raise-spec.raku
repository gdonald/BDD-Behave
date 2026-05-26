use BDD::Behave;
use BDD::Behave::Failures;

my class X::Raise::Demo is Exception {
  has $.code;
  method message { "raise-demo failure: code={$!code}" }
}

my class X::Raise::Sub is X::Raise::Demo { }

describe 'raise alias basics', {
  it 'passes when the block raises with die', {
    expect({ die "boom" }).to.raise;
  }

  it 'passes when the block throws a typed exception', {
    expect({ X::AdHoc.new(payload => 'oops').throw }).to.raise;
  }

  it 'fails when the block does not raise', {
    Failures.list = ();
    expect({ 1 + 1 }).to.raise;
    my $count = Failures.list.elems;
    Failures.list = ();

    expect($count).to.be(1);
  }

  it 'records the same failure wording as raise-error', {
    Failures.list = ();
    expect({ 42 }).to.raise;
    my $message = Failures.list[0].message;
    Failures.list = ();

    expect($message).to.be(
      'expected block to raise an error, but none was raised'
    );
  }
}

describe 'raise alias with non-Callable actuals', {
  it 'fails when given an Int', {
    Failures.list = ();
    expect(42).to.raise;
    my $count = Failures.list.elems;
    Failures.list = ();

    expect($count).to.be(1);
  }
}

describe 'raise alias negation', {
  it 'passes when the block does not raise', {
    expect({ 1 + 1 }).to.not.raise;
  }

  it 'fails when the block raises under negation', {
    Failures.list = ();
    expect({ die "boom" }).to.not.raise;
    my $count = Failures.list.elems;
    Failures.list = ();

    expect($count).to.be(1);
  }
}

describe 'raise alias with an exception type', {
  it 'passes when the raised exception matches the type', {
    expect({ X::Raise::Demo.new(:code(7)).throw })
      .to.raise(X::Raise::Demo);
  }

  it 'passes for a subclass of the expected type', {
    expect({ X::Raise::Sub.new(:code(9)).throw })
      .to.raise(X::Raise::Demo);
  }

  it 'fails when a different exception type is raised', {
    Failures.list = ();
    expect({ die "boom" }).to.raise(X::Raise::Demo);
    my $count = Failures.list.elems;
    Failures.list = ();

    expect($count).to.be(1);
  }
}

describe 'raise alias with type and message regex', {
  it 'passes when type and message both match', {
    expect({ X::Raise::Demo.new(:code(11)).throw })
      .to.raise(X::Raise::Demo, /'code=11'/);
  }

  it 'fails when the message does not match', {
    Failures.list = ();
    expect({ X::Raise::Demo.new(:code(11)).throw })
      .to.raise(X::Raise::Demo, /'code=99'/);
    my $count = Failures.list.elems;
    Failures.list = ();

    expect($count).to.be(1);
  }
}

describe 'raise alias with message-only regex', {
  it 'passes for any exception whose message matches', {
    expect({ die "alpha bravo" }).to.raise(/'bravo'/);
  }

  it 'fails when the regex does not match', {
    Failures.list = ();
    expect({ die "alpha" }).to.raise(/'bravo'/);
    my $count = Failures.list.elems;
    Failures.list = ();

    expect($count).to.be(1);
  }
}

describe 'raise alias chained with with-message', {
  it 'passes when the Str message matches exactly', {
    expect({ die "boom" }).to.raise.with-message('boom');
  }

  it 'passes when the Regex message matches', {
    expect({ die "alpha bravo" }).to.raise.with-message(/'bravo'/);
  }

  it 'fails when the Str message does not match', {
    Failures.list = ();
    expect({ die "boom" }).to.raise.with-message('bang');
    my $count = Failures.list.elems;
    Failures.list = ();

    expect($count).to.be(1);
  }
}
