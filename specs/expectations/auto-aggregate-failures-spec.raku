use BDD::Behave;
use BDD::Behave::Failures;
use BDD::Behave::Runner;
use BDD::Behave::SpecTree;

constant Suite        = BDD::Behave::SpecTree::Suite;
constant ExampleGroup = BDD::Behave::SpecTree::ExampleGroup;
constant Example      = BDD::Behave::SpecTree::Example;

sub silent-run($suite, *%runner-args) {
  my $sink = open '/dev/null', :w;
  my $*OUT = $sink;
  my $runner = BDD::Behave::Runner::Runner.new(|%runner-args);
  my $result = $runner.run($suite);
  $sink.close;
  ($runner, $result);
}

sub make-suite(&body) {
  my $suite = Suite.create(
    :description('synthetic'),
    :file('synthetic'.IO),
    :line(1),
  );
  body($suite);
  $suite;
}

describe 'automatic aggregation (runner default)', {
  it 'is off by default — exception flows to runner errors', {
    Failures.list = ();
    my $suite = make-suite(-> $s {
      my $ex = Example.new(
        :description('boom'), :file('synthetic'.IO), :line(10),
        :block({ die 'kaboom' }),
      );
      $s.add-example($ex);
    });
    my ($runner,) = silent-run($suite);
    expect(Failures.list.elems).to.be(0);
    expect($runner.result.failed).to.be(1);
    expect($runner.result.errors[0]<exception>.defined).to.be-truthy;
    Failures.list = ();
  }

  it 'with :aggregate-failures converts exceptions to unlabeled failures', {
    Failures.list = ();
    my $suite = make-suite(-> $s {
      my $ex = Example.new(
        :description('boom'), :file('synthetic'.IO), :line(10),
        :block({ die 'kaboom' }),
      );
      $s.add-example($ex);
    });
    my ($runner,) = silent-run($suite, :aggregate-failures);
    expect(Failures.list.elems).to.be(1);
    expect(Failures.list[0].aggregation-label).to.be-nil;
    expect(Failures.list[0].message).to.include('kaboom');
    Failures.list = ();
  }

  it 'with :aggregate-failures<label> labels every failure inside', {
    Failures.list = ();
    my $suite = make-suite(-> $s {
      my $ex = Example.new(
        :description('multi'), :file('synthetic'.IO), :line(20),
        :block({
          expect(1).to.be(2);
          expect('a').to.be('b');
        }),
      );
      $s.add-example($ex);
    });
    silent-run($suite, :aggregate-failures<run-label>);
    expect(Failures.list.elems).to.be(2);
    expect(Failures.list[0].aggregation-label).to.be('run-label');
    expect(Failures.list[1].aggregation-label).to.be('run-label');
    Failures.list = ();
  }
}

describe 'automatic aggregation (per-example metadata)', {
  it 'on `it` with :aggregate-failures wraps that one example', {
    Failures.list = ();
    my $suite = make-suite(-> $s {
      my $ex1 = Example.new(
        :description('agg'), :file('synthetic'.IO), :line(10),
        :block({ die 'first' }),
      );
      $ex1.set-metadata(:aggregate-failures(True));
      my $ex2 = Example.new(
        :description('plain'), :file('synthetic'.IO), :line(20),
        :block({ die 'second' }),
      );
      $s.add-example($ex1);
      $s.add-example($ex2);
    });
    my ($runner,) = silent-run($suite);
    expect(Failures.list.elems).to.be(1);
    expect(Failures.list[0].message).to.include('first');
    expect($runner.result.failed).to.be(2);
    Failures.list = ();
  }

  it 'with :aggregate-failures<label> labels in-block failures', {
    Failures.list = ();
    my $suite = make-suite(-> $s {
      my $ex = Example.new(
        :description('labeled'), :file('synthetic'.IO), :line(30),
        :block({
          expect(1).to.be(2);
          die 'after';
        }),
      );
      $ex.set-metadata(:aggregate-failures('api'));
      $s.add-example($ex);
    });
    silent-run($suite);
    expect(Failures.list.elems).to.be(2);
    expect(Failures.list[0].aggregation-label).to.be('api');
    expect(Failures.list[1].aggregation-label).to.be('api');
    Failures.list = ();
  }

  it 'wins over the runner default', {
    Failures.list = ();
    my $suite = make-suite(-> $s {
      my $ex = Example.new(
        :description('override'), :file('synthetic'.IO), :line(40),
        :block({ expect(1).to.be(2) }),
      );
      $ex.set-metadata(:aggregate-failures('example-wins'));
      $s.add-example($ex);
    });
    silent-run($suite, :aggregate-failures<runner-default>);
    expect(Failures.list[0].aggregation-label).to.be('example-wins');
    Failures.list = ();
  }
}

describe 'automatic aggregation (group metadata)', {
  it 'cascades from a group to every child example', {
    Failures.list = ();
    my $suite = make-suite(-> $s {
      my $g = ExampleGroup.new(
        :description('grp'), :file('synthetic'.IO), :line(5),
      );
      $g.set-metadata(:aggregate-failures('grp-label'));
      my $ex1 = Example.new(
        :description('a'), :file('synthetic'.IO), :line(10),
        :block({ expect(1).to.be(2) }),
      );
      my $ex2 = Example.new(
        :description('b'), :file('synthetic'.IO), :line(20),
        :block({ die 'in b' }),
      );
      $g.add-example($ex1);
      $g.add-example($ex2);
      $s.add-group($g);
    });
    silent-run($suite);
    expect(Failures.list.elems).to.be(2);
    expect(Failures.list[0].aggregation-label).to.be('grp-label');
    expect(Failures.list[1].aggregation-label).to.be('grp-label');
    Failures.list = ();
  }

  it 'leaf :aggregate-failures(False) opts out of an outer group default', {
    Failures.list = ();
    my $suite = make-suite(-> $s {
      my $g = ExampleGroup.new(
        :description('grp'), :file('synthetic'.IO), :line(5),
      );
      $g.set-metadata(:aggregate-failures(True));
      my $ex = Example.new(
        :description('opt-out'), :file('synthetic'.IO), :line(10),
        :block({ die 'still raised' }),
      );
      $ex.set-metadata(:aggregate-failures(False));
      $g.add-example($ex);
      $s.add-group($g);
    });
    my ($runner,) = silent-run($suite);
    expect(Failures.list.elems).to.be(0);
    expect($runner.result.errors[0]<exception>.defined).to.be-truthy;
    Failures.list = ();
  }
}

describe 'automatic aggregation (interaction with explicit aggregate-failures)', {
  it 'inner aggregate-failures label wins over an outer auto label', {
    Failures.list = ();
    my $suite = make-suite(-> $s {
      my $ex = Example.new(
        :description('nested'), :file('synthetic'.IO), :line(10),
        :block({
          expect(1).to.be(2);
          aggregate-failures 'inner', {
            expect(3).to.be(4);
          }
          expect(5).to.be(6);
        }),
      );
      $ex.set-metadata(:aggregate-failures('outer'));
      $s.add-example($ex);
    });
    silent-run($suite);
    expect(Failures.list.elems).to.be(3);
    expect(Failures.list[0].aggregation-label).to.be('outer');
    expect(Failures.list[1].aggregation-label).to.be('inner');
    expect(Failures.list[2].aggregation-label).to.be('outer');
    Failures.list = ();
  }
}

describe 'automatic aggregation (passing examples)', {
  it 'does not affect passing examples', {
    Failures.list = ();
    my $suite = make-suite(-> $s {
      my $ex = Example.new(
        :description('pass'), :file('synthetic'.IO), :line(10),
        :block({ expect(1).to.be(1) }),
      );
      $ex.set-metadata(:aggregate-failures('label'));
      $s.add-example($ex);
    });
    my ($runner,) = silent-run($suite);
    expect(Failures.list.elems).to.be(0);
    expect($runner.result.success).to.be-truthy;
    Failures.list = ();
  }
}
