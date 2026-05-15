use BDD::Behave;
use BDD::Behave::Failures;

describe 'be-kept matcher', {
  it 'passes when the promise is already kept', {
    expect(Promise.kept('done')).to.be-kept;
  }

  it 'passes for a promise that becomes kept before the timeout', {
    my $p = start { 'eventual value' }
    expect($p).to.be-kept;
  }

  it 'fails when the promise is broken', {
    Failures.list = ();
    expect(Promise.broken('oops')).to.be-kept;
    my $count = Failures.list.elems;
    Failures.list = ();
    expect($count).to.be(1);
  }

  it 'fails when the promise is still pending after the timeout', {
    Failures.list = ();
    my $vow = Promise.new;
    expect($vow).to.be-kept(0.05);
    my $count = Failures.list.elems;
    Failures.list = ();
    expect($count).to.be(1);
  }

  it 'fails when given a non-Promise actual', {
    Failures.list = ();
    expect(42).to.be-kept;
    my $count = Failures.list.elems;
    Failures.list = ();
    expect($count).to.be(1);
  }

  it 'records a Callable-shape message for non-Promise actuals', {
    Failures.list = ();
    expect(42).to.be-kept;
    my $message = Failures.list[0].message;
    Failures.list = ();
    expect($message).to.be('expected a Promise for be-kept, but got 42');
  }

  it 'surfaces the broken cause in the failure message', {
    Failures.list = ();
    expect(Promise.broken('boom')).to.be-kept;
    my $message = Failures.list[0].message;
    Failures.list = ();
    expect($message).to.include('but it was broken');
    expect($message).to.include('boom');
  }

  it 'reports the timeout in the failure message', {
    Failures.list = ();
    my $vow = Promise.new;
    expect($vow).to.be-kept(0.05);
    my $message = Failures.list[0].message;
    Failures.list = ();
    expect($message).to.include('still pending');
    expect($message).to.include('0.05');
  }
}

describe 'be-kept negation', {
  it 'passes when the promise is broken', {
    expect(Promise.broken('nope')).to.not.be-kept;
  }

  it 'fails when the promise is kept', {
    Failures.list = ();
    expect(Promise.kept('done')).to.not.be-kept;
    my $count = Failures.list.elems;
    Failures.list = ();
    expect($count).to.be(1);
  }
}

describe 'be-broken matcher', {
  it 'passes when the promise is already broken', {
    expect(Promise.broken('boom')).to.be-broken;
  }

  it 'passes for a promise that becomes broken before the timeout', {
    my $p = start { die 'eventual failure' }
    expect($p).to.be-broken;
  }

  it 'fails when the promise is kept', {
    Failures.list = ();
    expect(Promise.kept('done')).to.be-broken;
    my $count = Failures.list.elems;
    Failures.list = ();
    expect($count).to.be(1);
  }

  it 'fails when the promise is still pending after the timeout', {
    Failures.list = ();
    my $vow = Promise.new;
    expect($vow).to.be-broken(0.05);
    my $count = Failures.list.elems;
    Failures.list = ();
    expect($count).to.be(1);
  }

  it 'fails when given a non-Promise actual', {
    Failures.list = ();
    expect('hello').to.be-broken;
    my $count = Failures.list.elems;
    Failures.list = ();
    expect($count).to.be(1);
  }

  it 'reports the kept value in the failure message', {
    Failures.list = ();
    expect(Promise.kept('happy')).to.be-broken;
    my $message = Failures.list[0].message;
    Failures.list = ();
    expect($message).to.include('was kept with');
    expect($message).to.include('happy');
  }
}

describe 'be-broken negation', {
  it 'passes when the promise is kept', {
    expect(Promise.kept('done')).to.not.be-broken;
  }

  it 'fails when the promise is broken', {
    Failures.list = ();
    expect(Promise.broken('boom')).to.not.be-broken;
    my $count = Failures.list.elems;
    Failures.list = ();
    expect($count).to.be(1);
  }

  it 'surfaces the broken cause in the negated failure message', {
    Failures.list = ();
    expect(Promise.broken('boom')).to.not.be-broken;
    my $message = Failures.list[0].message;
    Failures.list = ();
    expect($message).to.include('boom');
  }
}

describe 'complete-within matcher', {
  it 'passes when the promise is already kept', {
    expect(Promise.kept('done')).to.complete-within(1);
  }

  it 'passes when the promise is already broken', {
    expect(Promise.broken('boom')).to.complete-within(1);
  }

  it 'passes when the promise completes before the duration elapses', {
    my $p = start { 'eventual value' }
    expect($p).to.complete-within(5);
  }

  it 'fails when the promise is still pending after the duration', {
    Failures.list = ();
    my $vow = Promise.new;
    expect($vow).to.complete-within(0.05);
    my $count = Failures.list.elems;
    Failures.list = ();
    expect($count).to.be(1);
  }

  it 'fails when given a non-Promise actual', {
    Failures.list = ();
    expect([]).to.complete-within(1);
    my $count = Failures.list.elems;
    Failures.list = ();
    expect($count).to.be(1);
  }

  it 'reports the duration in the failure message', {
    Failures.list = ();
    my $vow = Promise.new;
    expect($vow).to.complete-within(0.05);
    my $message = Failures.list[0].message;
    Failures.list = ();
    expect($message).to.include('complete within');
    expect($message).to.include('0.05');
    expect($message).to.include('still pending');
  }

  it 'preserves the duration as expected-value on Failure', {
    Failures.list = ();
    my $vow = Promise.new;
    expect($vow).to.complete-within(0.05);
    my $expected = Failures.list[0].expected;
    Failures.list = ();
    expect($expected).to.be(0.05);
  }
}

describe 'complete-within negation', {
  it 'passes when the promise is still pending after the duration', {
    my $vow = Promise.new;
    expect($vow).to.not.complete-within(0.05);
  }

  it 'fails when the promise is already kept', {
    Failures.list = ();
    expect(Promise.kept('done')).to.not.complete-within(1);
    my $count = Failures.list.elems;
    Failures.list = ();
    expect($count).to.be(1);
  }

  it 'fails when the promise is already broken', {
    Failures.list = ();
    expect(Promise.broken('boom')).to.not.complete-within(1);
    my $count = Failures.list.elems;
    Failures.list = ();
    expect($count).to.be(1);
  }
}
