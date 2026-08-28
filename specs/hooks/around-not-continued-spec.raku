use BDD::Behave;
use BDD::Behave::Runner;
use BDD::Behave::SpecTree;

constant Suite        = BDD::Behave::SpecTree::Suite;
constant ExampleGroup = BDD::Behave::SpecTree::ExampleGroup;
constant Example      = BDD::Behave::SpecTree::Example;

# An around-each hook that never calls its continuation leaves the example
# unrun, which the runner reports as a skip rather than as a pass.
sub suite-with-around-each(&hook-body, &example-body --> Suite) {
  my $suite = Suite.create(:description('around'), :file('synthetic'.IO), :line(1));
  my $group = ExampleGroup.new(:description('a group'), :file('synthetic'.IO), :line(1));
  $suite.add-group($group);
  $group.add-example(
    Example.new(:description('an example'), :file('synthetic'.IO), :line(2), :block(&example-body)),
  );
  $group.add-hook('around-each', &hook-body);
  $suite;
}

sub silent-run(Suite $suite --> BDD::Behave::Runner::RunResult) {
  my $sink = open '/dev/null', :w;
  my $*OUT = $sink;
  my $result = BDD::Behave::Runner::Runner.new.run($suite);
  $sink.close;
  $result;
}

describe 'an around-each hook that never calls its continuation', {
  let(:ran, { my $flag = [False]; $flag });

  let(:result, {
    silent-run(suite-with-around-each(-> &continue { Nil }, { ran()[0] = True }));
  });

  it 'counts the example as skipped', {
    expect(result().skipped).to.eq(1);
  }

  it 'counts no passing example', {
    expect(result().passed).to.eq(0);
  }

  it 'leaves the example block unrun', {
    result();
    expect(ran()[0]).to.be-falsy;
  }
}
