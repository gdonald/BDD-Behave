use BDD::Behave;
use BDD::Behave::Runner;
use BDD::Behave::SpecRegistry;
use BDD::Behave::Formatter::Tree;
use BDD::Behave::SpecTree;
use BDD::Behave::Failures;

constant Suite        = BDD::Behave::SpecTree::Suite;
constant ExampleGroup = BDD::Behave::SpecTree::ExampleGroup;
constant Example     = BDD::Behave::SpecTree::Example;

sub build-suite($file = 'fixture.raku', :@groups, :%suite-meta = %()) {
  my $suite = Suite.new(:description($file), :file($file.IO), :line(1));
  $suite.set-metadata(|%suite-meta) if %suite-meta.elems;
  $suite;
}

sub silent-runner(*%opts) {
  use BDD::Behave::Formatter;
  my role Silent does BDD::Behave::Formatter {
    method name(--> Str) { 'silent' }
  }
  my $fmt = (class :: does Silent { }).new;
  BDD::Behave::Runner::Runner.new(:formatter($fmt), :order<defined>, |%opts);
}

sub run-isolated($runner, $suite) {
  my Int $snap = Failures.list.elems;
  my $result = $runner.run($suite);
  Failures.list.splice($snap, Failures.list.elems - $snap)
    if Failures.list.elems > $snap;
  $result;
}

sub fail-with-fake-failure() {
  Failures.list.push(BDD::Behave::Failure.new(
    :file('fixture.raku'), :line(2), :given(1), :expected(2), :negated(False),
  ));
}

describe 'Runner retry mechanism', {
  it 'with retry=0 runs an example exactly once even when failing', {
    my $count = 0;
    my $suite = build-suite();
    $suite.add-example(Example.new(
      :description('always fails'),
      :file('fixture.raku'.IO), :line(2),
      :block(sub { $count++; fail-with-fake-failure(); }),
    ));

    my $runner = silent-runner(:retry(0));
    run-isolated($runner, $suite);

    expect($count).to.be(1);
    expect($runner.result.failed).to.be(1);
    expect($runner.result.passed).to.be(0);
  }

  it 'with retry=2 retries a failing example up to 3 total attempts', {
    my $count = 0;
    my $suite = build-suite();
    $suite.add-example(Example.new(
      :description('always fails'),
      :file('fixture.raku'.IO), :line(2),
      :block(sub { $count++; fail-with-fake-failure(); }),
    ));

    my $runner = silent-runner(:retry(2));
    run-isolated($runner, $suite);

    expect($count).to.be(3);
    expect($runner.result.failed).to.be(1);
  }

  it 'stops retrying as soon as an attempt passes', {
    my $count = 0;
    my $suite = build-suite();
    $suite.add-example(Example.new(
      :description('passes on second'),
      :file('fixture.raku'.IO), :line(2),
      :block(sub {
        $count++;
        fail-with-fake-failure() if $count < 2;
      }),
    ));

    my $runner = silent-runner(:retry(5));
    run-isolated($runner, $suite);

    expect($count).to.be(2);
    expect($runner.result.passed).to.be(1);
    expect($runner.result.failed).to.be(0);
  }

  it 'records a RetryRecord with the final outcome and attempt count', {
    my $count = 0;
    my $suite = build-suite();
    $suite.add-example(Example.new(
      :description('flaky'),
      :file('fixture.raku'.IO), :line(2),
      :block(sub {
        $count++;
        fail-with-fake-failure() if $count < 3;
      }),
    ));

    my $runner = silent-runner(:retry(4));
    run-isolated($runner, $suite);

    expect($runner.result.retry-records.elems).to.be(1);
    my $rec = $runner.result.retry-records[0];
    expect($rec.attempts).to.be(3);
    expect($rec.max-attempts).to.be(5);
    expect($rec.outcome).to.be('pass');
    expect($rec.location).to.be('fixture.raku:2');
  }

  it 'does not record a RetryRecord when no retry was needed', {
    my $suite = build-suite();
    $suite.add-example(Example.new(
      :description('always passes'),
      :file('fixture.raku'.IO), :line(2),
      :block(sub { }),
    ));

    my $runner = silent-runner(:retry(3));
    run-isolated($runner, $suite);

    expect($runner.result.retry-records.elems).to.be(0);
  }

  it 'records a fail outcome when all attempts fail', {
    my $count = 0;
    my $suite = build-suite();
    $suite.add-example(Example.new(
      :description('always fails'),
      :file('fixture.raku'.IO), :line(2),
      :block(sub { $count++; fail-with-fake-failure(); }),
    ));

    my $runner = silent-runner(:retry(2));
    run-isolated($runner, $suite);

    expect($runner.result.retry-records.elems).to.be(1);
    expect($runner.result.retry-records[0].outcome).to.be('fail');
    expect($runner.result.retry-records[0].attempts).to.be(3);
  }

  it 'per-example :retry metadata overrides the runner default', {
    my $count = 0;
    my $suite = build-suite();
    my $ex = Example.new(
      :description('flaky with :retry(4)'),
      :file('fixture.raku'.IO), :line(2),
      :block(sub {
        $count++;
        fail-with-fake-failure() if $count < 4;
      }),
    );
    $ex.set-metadata(:retry(4));
    $suite.add-example($ex);

    my $runner = silent-runner(:retry(1));
    run-isolated($runner, $suite);

    expect($count).to.be(4);
    expect($runner.result.passed).to.be(1);
  }

  it 'inherited :retry from an enclosing group applies to descendants', {
    my $count = 0;
    my $suite = build-suite();
    my $group = ExampleGroup.new(
      :description('flaky group'),
      :file('fixture.raku'.IO), :line(1),
    );
    $group.set-metadata(:retry(2));
    $group.add-example(Example.new(
      :description('inherits retry'),
      :file('fixture.raku'.IO), :line(2),
      :block(sub {
        $count++;
        fail-with-fake-failure() if $count < 3;
      }),
    ));
    $suite.add-group($group);

    my $runner = silent-runner(:retry(0));
    run-isolated($runner, $suite);

    expect($count).to.be(3);
    expect($runner.result.passed).to.be(1);
  }

  it 'clears intermediate failures from Failures.list so only the last attempt is reported', {
    my $count = 0;
    my $suite = build-suite();
    $suite.add-example(Example.new(
      :description('flaky'),
      :file('fixture.raku'.IO), :line(2),
      :block(sub {
        $count++;
        fail-with-fake-failure() if $count < 2;
      }),
    ));

    my $runner = silent-runner(:retry(3));
    my $snap-before = Failures.list.elems;
    $runner.run($suite);
    my $delta = Failures.list.elems - $snap-before;
    Failures.list.splice($snap-before, $delta) if $delta > 0;
    expect($delta).to.be(0);
  }

  it 'does not retry pending examples', {
    my $suite = build-suite();
    my $ex = Example.new(
      :description('still to do'),
      :file('fixture.raku'.IO), :line(2),
      :block(sub { }),
    );
    $ex.pending = True;
    $suite.add-example($ex);

    my $runner = silent-runner(:retry(5));
    run-isolated($runner, $suite);

    expect($runner.result.pending).to.be(1);
    expect($runner.result.retry-records.elems).to.be(0);
  }

  it 'does not retry skipped examples', {
    my $suite = build-suite();
    my $ex = Example.new(
      :description('skip me'),
      :file('fixture.raku'.IO), :line(2),
      :block(sub { }),
    );
    $ex.set-metadata(:skipped(True));
    $suite.add-example($ex);

    my $runner = silent-runner(:retry(5));
    run-isolated($runner, $suite);

    expect($runner.result.skipped).to.be(1);
    expect($runner.result.retry-records.elems).to.be(0);
  }
}
