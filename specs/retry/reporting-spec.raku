use BDD::Behave;
use BDD::Behave::Runner;
use BDD::Behave::Formatter::Progress;
use BDD::Behave::Formatter::Tree;
use BDD::Behave::SpecTree;
use BDD::Behave::Failures;
use Test::Output;

constant Suite   = BDD::Behave::SpecTree::Suite;
constant Example = BDD::Behave::SpecTree::Example;

sub fail-with-fake-failure() {
  Failures.list.push(BDD::Behave::Failure.new(
    :file('fixture.raku'), :line(2), :given(1), :expected(2), :negated(False),
  ));
}

sub build-flaky-suite($passes-on, :$description = 'flaky') {
  my $suite = Suite.new(:description('fixture.raku'), :file('fixture.raku'.IO), :line(1));
  my $count = 0;
  $suite.add-example(Example.new(
    :description($description),
    :file('fixture.raku'.IO), :line(2),
    :block(sub {
      $count++;
      fail-with-fake-failure() if $count < $passes-on;
    }),
  ));
  $suite;
}

sub capture-isolated(&body) {
  my $snap = Failures.list.elems;
  my $output = stdout-from { &body() };
  Failures.list.splice($snap, Failures.list.elems - $snap)
    if Failures.list.elems > $snap;
  $output;
}

describe 'Retry reporting output', {
  it 'progress formatter prints R for each retry attempt', {
    my $suite  = build-flaky-suite(3);
    my $output = capture-isolated {
      my $runner = BDD::Behave::Runner::Runner.new(
        :formatter(BDD::Behave::Formatter::Progress.new),
        :retry(2),
        :order<defined>,
      );
      $runner.run($suite);
    };
    expect($output.contains('R')).to.be-truthy;
    expect($output.contains('Retried 1 example:')).to.be-truthy;
  }

  it 'tree formatter prints a RETRY (attempt N of M) line between attempts', {
    my $suite  = build-flaky-suite(2);
    my $output = capture-isolated {
      my $runner = BDD::Behave::Runner::Runner.new(
        :formatter(BDD::Behave::Formatter::Tree.new),
        :retry(2),
        :order<defined>,
      );
      $runner.run($suite);
    };
    expect($output.contains('RETRY (attempt 1 of 3)')).to.be-truthy;
  }

  it 'the retry-summary section omits when no retries occurred', {
    my $suite = Suite.new(:description('fixture.raku'), :file('fixture.raku'.IO), :line(1));
    $suite.add-example(Example.new(
      :description('passes immediately'),
      :file('fixture.raku'.IO), :line(2),
      :block(sub { }),
    ));
    my $output = capture-isolated {
      my $runner = BDD::Behave::Runner::Runner.new(
        :formatter(BDD::Behave::Formatter::Progress.new),
        :retry(3),
        :order<defined>,
      );
      $runner.run($suite);
    };
    expect($output.contains('Retried')).to.be-falsy;
  }

  it 'reports a failing retried example with [FAIL] in the summary', {
    my $suite = build-flaky-suite(99);
    my $output = capture-isolated {
      my $runner = BDD::Behave::Runner::Runner.new(
        :formatter(BDD::Behave::Formatter::Progress.new),
        :retry(2),
        :order<defined>,
      );
      $runner.run($suite);
    };
    expect($output.contains('[FAIL]')).to.be-truthy;
    expect($output.contains('3/3 attempts')).to.be-truthy;
  }

  it 'reports a passing retried example with [PASS] in the summary', {
    my $suite = build-flaky-suite(2);
    my $output = capture-isolated {
      my $runner = BDD::Behave::Runner::Runner.new(
        :formatter(BDD::Behave::Formatter::Progress.new),
        :retry(2),
        :order<defined>,
      );
      $runner.run($suite);
    };
    expect($output.contains('[PASS]')).to.be-truthy;
    expect($output.contains('2/3 attempts')).to.be-truthy;
  }
}
