use BDD::Behave;
use BDD::Behave::Failures;
use BDD::Behave::Matcher;
use BDD::Behave::Matcher::Async;
use BDD::Behave::Matcher::Numeric;

describe 'eventually matcher', {
  it 'passes when the block already matches on the first iteration', {
    my $state = 5;
    expect({ $state }).to.eventually.be(5);
  }

  it 'passes when the block eventually matches', {
    my $state    = 0;
    my $deadline = now + 0.2;
    start { sleep 0.05; $state = 42; }
    expect({ $state }).to.eventually(:timeout(1), :interval(0.01)).be(42);
  }

  it 'fails when the block never matches within the timeout', {
    Failures.list = ();
    expect({ 0 }).to.eventually(:timeout(0.05), :interval(0.01)).be(99);
    my $count = Failures.list.elems;
    Failures.list = ();
    expect($count).to.be(1);
  }

  it 'reports timing details in the failure message', {
    Failures.list = ();
    expect({ 0 }).to.eventually(:timeout(0.05), :interval(0.01)).be(99);
    my $message = Failures.list[0].message;
    Failures.list = ();
    expect($message).to.start-with('eventually:');
    expect($message).to.include('iteration');
  }

  it 'fails when given a non-Callable actual', {
    Failures.list = ();
    expect(42).to.eventually.be(42);
    my $count = Failures.list.elems;
    Failures.list = ();
    expect($count).to.be(1);
  }

  it 'records a Callable-shape message for non-Callable actuals', {
    Failures.list = ();
    expect(42).to.eventually.be(42);
    my $message = Failures.list[0].message;
    Failures.list = ();
    expect($message).to.be('expected a Callable for eventually, but got 42');
  }
}

describe 'eventually with various matchers', {
  it 'works with eq for structural equality', {
    my $state    = [];
    start { sleep 0.05; $state.push(1, 2, 3); }
    expect({ $state.clone }).to.eventually(:timeout(1), :interval(0.01)).eq([1, 2, 3]);
  }

  it 'works with match for regex matching', {
    my $state    = '';
    start { sleep 0.05; $state = 'done loading'; }
    expect({ $state }).to.eventually(:timeout(1), :interval(0.01)).match(/done/);
  }

  it 'works with include for collection membership', {
    my $state    = [];
    start { sleep 0.05; $state.push('hello'); }
    expect({ $state.clone }).to.eventually(:timeout(1), :interval(0.01)).include('hello');
  }

  it 'works with be-truthy', {
    my $state    = False;
    start { sleep 0.05; $state = True; }
    expect({ $state }).to.eventually(:timeout(1), :interval(0.01)).be-truthy;
  }

  it 'works with be-greater-than', {
    my $state    = 0;
    start { sleep 0.05; $state = 100; }
    expect({ $state }).to.eventually(:timeout(1), :interval(0.01)).be-greater-than(50);
  }

  it 'works with be-a for type checking', {
    my $state    = Nil;
    start { sleep 0.05; $state = 42; }
    expect({ $state }).to.eventually(:timeout(1), :interval(0.01)).be-a(Int);
  }
}

describe 'eventually with custom matcher via matches-with', {
  it 'accepts a Matcher instance directly', {
    my $state    = 0;
    start { sleep 0.05; $state = 10; }
    expect({ $state }).to.eventually(:timeout(1), :interval(0.01))
                       .matches-with(BeGreaterThanMatcher.new(:expected(5)));
  }
}

describe 'eventually negation', {
  it 'passes when the block never matches within the window', {
    expect({ 0 }).to.not.eventually(:timeout(0.05), :interval(0.01)).be(99);
  }

  it 'fails when the block matches at any point in the window', {
    Failures.list = ();
    expect({ 5 }).to.not.eventually(:timeout(0.05), :interval(0.01)).be(5);
    my $count = Failures.list.elems;
    Failures.list = ();
    expect($count).to.be(1);
  }

  it 'reports the iteration count in the negated failure message', {
    Failures.list = ();
    expect({ 5 }).to.not.eventually(:timeout(0.05), :interval(0.01)).be(5);
    my $message = Failures.list[0].message;
    Failures.list = ();
    expect($message).to.include('matched');
    expect($message).to.include('iteration');
  }
}

describe 'eventually with throwing blocks', {
  it 'treats a thrown exception as a miss and keeps polling', {
    my $count = 0;
    my $block = {
      $count++;
      die "not yet" if $count < 3;
      'ready';
    };
    expect($block).to.eventually(:timeout(1), :interval(0.01)).be('ready');
  }

  it 'reports the exception in the failure message when never recovers', {
    Failures.list = ();
    expect({ die "always fails" }).to.eventually(:timeout(0.05), :interval(0.01)).be(1);
    my $message = Failures.list[0].message;
    Failures.list = ();
    expect($message).to.include('block threw');
    expect($message).to.include('always fails');
  }
}

describe 'eventually Failure metadata', {
  it 'preserves the Callable in Failure.given', {
    Failures.list = ();
    my $block = { 0 };
    expect($block).to.eventually(:timeout(0.05), :interval(0.01)).be(99);
    my $given = Failures.list[0].given;
    Failures.list = ();
    expect($given).to.be-a(Callable);
  }

  it 'carries the inner matcher expected value in Failure.expected', {
    Failures.list = ();
    expect({ 0 }).to.eventually(:timeout(0.05), :interval(0.01)).be(99);
    my $expected = Failures.list[0].expected;
    Failures.list = ();
    expect($expected).to.be(99);
  }

  it 'sets negated on the recorded Failure under .not', {
    Failures.list = ();
    expect({ 5 }).to.not.eventually(:timeout(0.05), :interval(0.01)).be(5);
    my $negated = Failures.list[0].negated;
    Failures.list = ();
    expect($negated).to.be-truthy;
  }
}
