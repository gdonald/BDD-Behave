use BDD::Behave;
use BDD::Behave::Failures;

describe 'raise-error matcher basics', {
  it 'passes when the block raises with die', {
    expect({ die "boom" }).to.raise-error;
  }

  it 'passes when the block throws a typed exception', {
    expect({ X::AdHoc.new(payload => 'oops').throw }).to.raise-error;
  }

  it 'passes when an exception propagates from nested code', {
    my sub inner { die "nested" }
    expect({ inner() }).to.raise-error;
  }

  it 'fails when the block does not raise', {
    Failures.list = ();
    expect({ 1 + 1 }).to.raise-error;
    my $count = Failures.list.elems;
    Failures.list = ();
    expect($count).to.be(1);
  }

  it 'fails when the block returns normally with a value', {
    Failures.list = ();
    expect({ 'all good' }).to.raise-error;
    my $count = Failures.list.elems;
    Failures.list = ();
    expect($count).to.be(1);
  }

  it 'records a matcher-supplied failure message on the no-error case', {
    Failures.list = ();
    expect({ 42 }).to.raise-error;
    my $message = Failures.list[0].message;
    Failures.list = ();
    expect($message).to.be(
      'expected block to raise an error, but none was raised'
    );
  }
}

describe 'raise-error with non-Callable actuals', {
  it 'fails when given an Int', {
    Failures.list = ();
    expect(42).to.raise-error;
    my $count = Failures.list.elems;
    Failures.list = ();
    expect($count).to.be(1);
  }

  it 'fails when given a Str', {
    Failures.list = ();
    expect('hello').to.raise-error;
    my $count = Failures.list.elems;
    Failures.list = ();
    expect($count).to.be(1);
  }

  it 'fails when given Nil', {
    Failures.list = ();
    expect(Nil).to.raise-error;
    my $count = Failures.list.elems;
    Failures.list = ();
    expect($count).to.be(1);
  }

  it 'records a Callable-shape message for non-Callable actuals', {
    Failures.list = ();
    expect(42).to.raise-error;
    my $message = Failures.list[0].message;
    Failures.list = ();
    expect($message).to.be('expected a Callable, but got 42');
  }
}

describe 'raise-error negation', {
  it 'passes when the block does not raise', {
    expect({ 1 + 1 }).to.not.raise-error;
  }

  it 'fails when the block raises under negation', {
    Failures.list = ();
    expect({ die "boom" }).to.not.raise-error;
    my $count = Failures.list.elems;
    Failures.list = ();
    expect($count).to.be(1);
  }

  it 'records a negated failure message that includes the exception detail', {
    Failures.list = ();
    expect({ die "boom" }).to.not.raise-error;
    my $message = Failures.list[0].message;
    my $negated = Failures.list[0].negated;
    Failures.list = ();
    expect($message).to.include(
      'expected block not to raise an error, but one was raised'
    );
    expect($message).to.include('X::AdHoc');
    expect($message).to.include('boom');
    expect($negated).to.be-truthy;
  }
}

describe 'raise-error preserves Failure metadata', {
  it 'preserves Failure.given as the block when no error is raised', {
    Failures.list = ();
    my $block = { 99 };
    expect($block).to.raise-error;
    my $given = Failures.list[0].given;
    Failures.list = ();
    expect($given ~~ Callable).to.be-truthy;
  }

  it 'records negated when called via .not', {
    Failures.list = ();
    expect({ die "x" }).to.not.raise-error;
    my $negated = Failures.list[0].negated;
    Failures.list = ();
    expect($negated).to.be-truthy;
  }
}

my class X::Behave::Demo is Exception {
  has $.code;
  method message { "demo failure: code={$!code}" }
}

my class X::Behave::Sub is X::Behave::Demo { }

my role X::Behave::Roleish { }

my class X::Behave::WithRole is Exception does X::Behave::Roleish {
  method message { 'with-role failure' }
}

describe 'raise-error with an exception type', {
  it 'passes when the raised exception matches the type', {
    expect({ X::Behave::Demo.new(:code(7)).throw })
      .to.raise-error(X::Behave::Demo);
  }

  it 'passes for a subclass of the expected type', {
    expect({ X::Behave::Sub.new(:code(9)).throw })
      .to.raise-error(X::Behave::Demo);
  }

  it 'passes for a class that does the expected role', {
    expect({ X::Behave::WithRole.new.throw })
      .to.raise-error(X::Behave::Roleish);
  }

  it 'fails when a different exception type is raised', {
    Failures.list = ();
    expect({ die "boom" }).to.raise-error(X::Behave::Demo);
    my $count = Failures.list.elems;
    my $msg   = Failures.list[0].message;
    Failures.list = ();
    expect($count).to.be(1);
    expect($msg).to.include('expected block to raise X::Behave::Demo');
    expect($msg).to.include('but raised');
    expect($msg).to.include('X::AdHoc');
    expect($msg).to.include('boom');
  }

  it 'fails when nothing was raised', {
    Failures.list = ();
    expect({ 1 + 1 }).to.raise-error(X::Behave::Demo);
    my $count = Failures.list.elems;
    my $msg   = Failures.list[0].message;
    Failures.list = ();
    expect($count).to.be(1);
    expect($msg).to.be(
      'expected block to raise X::Behave::Demo, but none was raised'
    );
  }

  it 'records the expected type in Failure.expected', {
    Failures.list = ();
    expect({ 1 + 1 }).to.raise-error(X::Behave::Demo);
    my $expected = Failures.list[0].expected;
    Failures.list = ();
    expect($expected === X::Behave::Demo).to.be-truthy;
  }
}

describe 'raise-error with type and message pattern', {
  it 'passes when type and message both match', {
    expect({ X::Behave::Demo.new(:code(11)).throw })
      .to.raise-error(X::Behave::Demo, /'code=11'/);
  }

  it 'fails when the type matches but the message does not', {
    Failures.list = ();
    expect({ X::Behave::Demo.new(:code(11)).throw })
      .to.raise-error(X::Behave::Demo, /'code=99'/);
    my $count = Failures.list.elems;
    my $msg   = Failures.list[0].message;
    Failures.list = ();
    expect($count).to.be(1);
    expect($msg).to.include('with message matching');
    expect($msg).to.include('but raised X::Behave::Demo');
    expect($msg).to.include('code=11');
  }

  it 'fails when the type does not match even if the regex would', {
    Failures.list = ();
    expect({ die "code=11" }).to.raise-error(X::Behave::Demo, /'code=11'/);
    my $count = Failures.list.elems;
    my $msg   = Failures.list[0].message;
    Failures.list = ();
    expect($count).to.be(1);
    expect($msg).to.include('expected block to raise X::Behave::Demo');
    expect($msg).to.include('with message matching');
  }
}

describe 'raise-error with message pattern only', {
  it 'passes for any exception whose message matches the regex', {
    expect({ die "alpha bravo" }).to.raise-error(/'bravo'/);
  }

  it 'passes regardless of exception type so long as the regex matches', {
    expect({ X::Behave::Demo.new(:code(3)).throw })
      .to.raise-error(/'code=3'/);
  }

  it 'fails when the regex does not match', {
    Failures.list = ();
    expect({ die "alpha" }).to.raise-error(/'bravo'/);
    my $count = Failures.list.elems;
    my $msg   = Failures.list[0].message;
    Failures.list = ();
    expect($count).to.be(1);
    expect($msg).to.include('expected block to raise an error');
    expect($msg).to.include('with message matching');
    expect($msg).to.include('but raised');
    expect($msg).to.include('alpha');
  }
}

describe 'raise-error.with-message (Str)', {
  it 'passes when the message matches exactly', {
    expect({ die "boom" }).to.raise-error.with-message('boom');
  }

  it 'passes when chained after a typed raise-error', {
    expect({ X::Behave::Demo.new(:code(7)).throw })
      .to.raise-error(X::Behave::Demo).with-message('demo failure: code=7');
  }

  it 'fails when the message does not match', {
    Failures.list = ();
    expect({ die "boom" }).to.raise-error.with-message('bang');
    my $count = Failures.list.elems;
    my $msg   = Failures.list[0].message;
    Failures.list = ();
    expect($count).to.be(1);
    expect($msg).to.include('with message');
    expect($msg).to.include('"bang"');
    expect($msg).to.include('but raised');
    expect($msg).to.include('boom');
  }

  it 'fails when nothing is raised', {
    Failures.list = ();
    expect({ 1 + 1 }).to.raise-error.with-message('boom');
    my $count = Failures.list.elems;
    my $msg   = Failures.list[0].message;
    Failures.list = ();
    expect($count).to.be(1);
    expect($msg).to.be(
      'expected block to raise an error with message "boom", but none was raised'
    );
  }

  it 'records only one failure when the entire chain fails', {
    Failures.list = ();
    expect({ 1 + 1 }).to.raise-error(X::Behave::Demo).with-message('boom');
    my $count = Failures.list.elems;
    Failures.list = ();
    expect($count).to.be(1);
  }

  it 'records the expected message in Failure.expected', {
    Failures.list = ();
    expect({ 1 + 1 }).to.raise-error.with-message('boom');
    my $expected = Failures.list[0].expected;
    Failures.list = ();
    expect($expected).to.be('boom');
  }
}

describe 'raise-error.with-message (Regex)', {
  it 'passes when the regex matches the message', {
    expect({ die "alpha bravo" }).to.raise-error.with-message(/'bravo'/);
  }

  it 'passes when chained after a typed raise-error', {
    expect({ X::Behave::Demo.new(:code(11)).throw })
      .to.raise-error(X::Behave::Demo).with-message(/'code=11'/);
  }

  it 'fails when the regex does not match', {
    Failures.list = ();
    expect({ die "alpha" }).to.raise-error.with-message(/'bravo'/);
    my $count = Failures.list.elems;
    my $msg   = Failures.list[0].message;
    Failures.list = ();
    expect($count).to.be(1);
    expect($msg).to.include('with message matching');
    expect($msg).to.include('but raised');
    expect($msg).to.include('alpha');
  }

  it 'replaces an earlier failure when reapplied with a different pattern', {
    Failures.list = ();
    my $exp = expect({ die "boom" }).to.raise-error.with-message(/'bang'/);
    my $after-first = Failures.list.elems;
    $exp.with-message(/'boom'/);
    my $after-second = Failures.list.elems;
    Failures.list = ();
    expect($after-first).to.be(1);
    expect($after-second).to.be(0);
  }
}

describe 'raise-error.with-message under negation', {
  it 'passes when the message does not match under .not', {
    expect({ die "boom" }).to.not.raise-error.with-message('bang');
  }

  it 'passes when nothing is raised under .not', {
    expect({ 1 + 1 }).to.not.raise-error.with-message('boom');
  }

  it 'fails when the message matches under .not', {
    Failures.list = ();
    expect({ die "boom" }).to.not.raise-error.with-message('boom');
    my $count = Failures.list.elems;
    my $msg   = Failures.list[0].message;
    Failures.list = ();
    expect($count).to.be(1);
    expect($msg).to.include('expected block not to raise an error');
    expect($msg).to.include('with message "boom"');
  }
}

describe 'raise-error typed negation', {
  it 'passes when a different type is raised under .not(Type)', {
    expect({ die "boom" }).to.not.raise-error(X::Behave::Demo);
  }

  it 'passes when nothing is raised under .not(Type)', {
    expect({ 1 + 1 }).to.not.raise-error(X::Behave::Demo);
  }

  it 'fails when the forbidden type is raised', {
    Failures.list = ();
    expect({ X::Behave::Demo.new(:code(5)).throw })
      .to.not.raise-error(X::Behave::Demo);
    my $count = Failures.list.elems;
    my $msg   = Failures.list[0].message;
    Failures.list = ();
    expect($count).to.be(1);
    expect($msg).to.include('expected block not to raise X::Behave::Demo');
    expect($msg).to.include('X::Behave::Demo');
    expect($msg).to.include('code=5');
  }
}
