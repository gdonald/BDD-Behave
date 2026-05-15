use BDD::Behave;
use BDD::Behave::SpecRegistry;
use BDD::Behave::SpecTree;
use BDD::Behave::Runner;

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

my $body-should-not-run = 0;

describe 'pending-spec fixture', {
  pending 'not yet implemented', {
    $body-should-not-run++;
  }

  pending 'no-block form needs an external service';

  pending 'pending with metadata', :tag<wip>, {
    $body-should-not-run++;
  }
}

sub find-fixture() {
  registry().suites
    .first({ .file.basename eq 'pending-spec.raku' })
    .groups.first(*.description eq 'pending-spec fixture');
}

describe 'pending', {
  it 'registers an example with the reason as description', {
    my $ex = find-fixture().examples.first(*.description eq 'not yet implemented');
    expect($ex.defined).to.be-truthy;
  }

  it 'marks the example as pending', {
    my $ex = find-fixture().examples.first(*.description eq 'not yet implemented');
    expect($ex.pending).to.be-truthy;
  }

  it 'stores the reason as pending-reason metadata', {
    my $ex = find-fixture().examples.first(*.description eq 'not yet implemented');
    expect($ex.get-metadata('pending-reason')).to.be('not yet implemented');
  }

  it 'does not execute the block during registration', {
    expect($body-should-not-run).to.be(0);
  }

  it 'supports the no-block form for the reason-only case', {
    my $ex = find-fixture().examples.first(*.description eq 'no-block form needs an external service');
    expect($ex.defined).to.be-truthy;
    expect($ex.pending).to.be-truthy;
  }

  it 'forwards tag metadata to the underlying example', {
    my $ex = find-fixture().examples.first(*.description eq 'pending with metadata');
    expect($ex.tags).to.include('wip');
    expect($ex.pending).to.be-truthy;
  }

  it 'increments the runner pending counter and skips execution', {
    my $synthetic = Suite.create(:description('s'), :file('synthetic'.IO), :line(1));
    my $group     = ExampleGroup.new(:description('g'), :file('synthetic'.IO), :line(1));
    $synthetic.add-group($group);

    my $ex = Example.new(
      :description('pending example'),
      :file('synthetic'.IO),
      :line(5),
      :block({ die 'must not run' }),
    );
    $ex.mark-pending(:reason('todo'));
    $group.add-example($ex);

    my $result = silent-run($synthetic);

    expect($result.pending).to.be(1);
    expect($result.failed).to.be(0);
    expect($result.passed).to.be(0);
  }

  it 'is distinct from xit (xit increments skipped, not pending)', {
    my $synthetic = Suite.create(:description('s'), :file('synthetic'.IO), :line(1));
    my $group     = ExampleGroup.new(:description('g'), :file('synthetic'.IO), :line(1));
    $synthetic.add-group($group);

    my $skipped = Example.new(
      :description('skipped via xit'),
      :file('synthetic'.IO), :line(5),
      :block({ die 'must not run' }),
    );
    $skipped.set-metadata(:skipped(True));
    $group.add-example($skipped);

    my $pending = Example.new(
      :description('pending via pending'),
      :file('synthetic'.IO), :line(6),
      :block({ die 'must not run' }),
    );
    $pending.mark-pending(:reason('todo'));
    $group.add-example($pending);

    my $result = silent-run($synthetic);

    expect($result.pending).to.be(1);
    expect($result.skipped).to.be(1);
  }
}
