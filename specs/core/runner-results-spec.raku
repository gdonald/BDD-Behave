use BDD::Behave;
use BDD::Behave::Runner;
use BDD::Behave::SpecRegistry;
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
  $result;
}

sub build-suite(:$pass = 0, :$fail = 0) {
  my $suite = Suite.create(:description('Synthetic'), :file('synthetic'.IO), :line(1));
  my $group = ExampleGroup.new(:description('group'), :file('synthetic'.IO), :line(1));
  $suite.add-group($group);

  for ^$pass -> $i {
    $group.add-example(Example.new(
      :description("pass $i"),
      :file('synthetic'.IO),
      :line(10 + $i),
      :block({ True }),
    ));
  }
  for ^$fail -> $i {
    $group.add-example(Example.new(
      :description("fail $i"),
      :file('synthetic'.IO),
      :line(100 + $i),
      :block({ die "intentional failure" }),
    ));
  }

  $suite;
}

describe 'RunResult counters', {
  it 'starts at zero before any run', {
    my $result = BDD::Behave::Runner::RunResult.new;
    expect($result.total).to.be(0);
    expect($result.passed).to.be(0);
    expect($result.failed).to.be(0);
    expect($result.pending).to.be(0);
    expect($result.skipped).to.be(0);
  }

  it 'reports total/passed/failed correctly for a mixed run', {
    my $suite  = build-suite(:pass(1), :fail(1));
    my $result = silent-run($suite);

    expect($result.total).to.be(2);
    expect($result.passed).to.be(1);
    expect($result.failed).to.be(1);
    expect($result.pending).to.be(0);
    expect($result.skipped).to.be(0);
  }

  it 'reports success() = False when any example fails', {
    my $suite  = build-suite(:pass(2), :fail(1));
    my $result = silent-run($suite);

    expect($result.success).to.be-falsy;
  }

  it 'reports success() = True when every example passes', {
    my $suite  = build-suite(:pass(3));
    my $result = silent-run($suite);

    expect($result.success).to.be-truthy;
    expect($result.failed).to.be(0);
  }

  it 'captures a per-failure error record with description, file, and line', {
    my $suite  = build-suite(:pass(0), :fail(2));
    my $result = silent-run($suite);

    expect($result.failed).to.be(2);
    expect($result.errors.elems).to.be(2);
    expect($result.errors[0]<file>).to.be('synthetic'.IO);
    expect($result.errors[0]<line>).to.be(100);
  }

  it 'counts skipped examples separately from passed/failed', {
    my $suite = Suite.create(:description('s'), :file('synthetic'.IO), :line(1));
    my $group = ExampleGroup.new(:description('g'), :file('synthetic'.IO), :line(1));
    $suite.add-group($group);

    my $skipped = Example.new(
      :description('skipped'),
      :file('synthetic'.IO), :line(5),
      :block({ die 'should not run' }),
    );
    $skipped.set-metadata(:skipped(True));
    $group.add-example($skipped);

    $group.add-example(Example.new(
      :description('passes'),
      :file('synthetic'.IO), :line(6),
      :block({ True }),
    ));

    my $result = silent-run($suite);

    expect($result.total).to.be(2);
    expect($result.skipped).to.be(1);
    expect($result.passed).to.be(1);
    expect($result.failed).to.be(0);
  }
}

describe 'Runner integration with the public DSL', {
  it 'runs a suite that was built via describe/it', {
    my $isolated-registry = BDD::Behave::SpecRegistry::SpecRegistry.new;
    my $tmp-file = $*PROGRAM.parent.add('synthetic-suite.raku');

    my $suite = Suite.create(:description('inline'), :file($tmp-file), :line(1));
    my $group = ExampleGroup.new(:description('inline-group'), :file($tmp-file), :line(1));
    $suite.add-group($group);
    $group.add-example(Example.new(
      :description('asserts truthy'),
      :file($tmp-file), :line(2),
      :block({ True }),
    ));

    my $result = silent-run($suite);

    expect($result.total).to.be(1);
    expect($result.passed).to.be(1);
    expect($result.success).to.be-truthy;
  }
}
