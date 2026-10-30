use BDD::Behave;
use BDD::Behave::Runner;
use BDD::Behave::SpecTree;
use Test::Output;

constant Runner       = BDD::Behave::Runner::Runner;
constant Suite        = BDD::Behave::SpecTree::Suite;
constant ExampleGroup = BDD::Behave::SpecTree::ExampleGroup;
constant Example      = BDD::Behave::SpecTree::Example;

sub recording-example(@log, Str $description = 'an example', Int $line = 10 --> Example) {
  Example.new(:$description, :file('synthetic'.IO), :$line, :block({ @log.push($description) }));
}

sub new-group(Str $description = 'a group' --> ExampleGroup) {
  ExampleGroup.new(:$description, :file('synthetic'.IO), :line(5));
}

sub run-group(ExampleGroup $group --> Hash) {
  my $suite = Suite.create(:description('hooks'), :file('synthetic'.IO), :line(1));
  $suite.add-group($group);

  my $result;
  stderr-from({
    stdout-from({ $result = Runner.new(:order<defined>, :format('progress')).run($suite) });
  });

  %( :$result );
}

describe 'a before-each hook that throws', {
  let(:log, { [] });

  let(:outcome, {
    my @log := log();
    my $group = new-group();
    $group.add-example(recording-example(@log));
    $group.add-hook('before-each', { die 'lead create failed' });
    $group.add-hook('before-each', { @log.push('second before-each') });
    $group.add-hook('after-each', { @log.push('after-each') });
    run-group($group);
  });

  it 'fails the example', {
    expect(outcome()<result>.failed).to.be(1);
  }

  it 'skips the example body and the later before-each hooks, and still runs the after-each hook', {
    outcome();
    expect(log()).to.eq(['after-each']);
  }
}

describe 'an after-each hook that throws', {
  let(:log, { [] });

  let(:outcome, {
    my @log := log();
    my $group = new-group();
    $group.add-example(recording-example(@log));
    $group.add-hook('after-each', { die 'cleanup failed' });
    $group.add-hook('after-each', { @log.push('second after-each') });
    run-group($group);
  });

  it 'fails an example that passed', {
    expect(outcome()<result>.failed).to.be(1);
  }

  it 'still runs the other after-each hooks', {
    outcome();
    expect(log()).to.eq(['an example', 'second after-each']);
  }
}

describe 'a before-all hook that throws', {
  let(:log, { [] });

  let(:outcome, {
    my @log := log();
    my $group = new-group();
    $group.add-example(recording-example(@log));

    my $nested = new-group('a nested group');
    $nested.add-example(recording-example(@log, 'a nested example', 20));
    $nested.add-hook('before-all', { @log.push('nested before-all') });
    $group.add-group($nested);

    $group.add-hook('before-all', { die 'seed failed' });
    $group.add-hook('after-all', { @log.push('after-all') });
    run-group($group);
  });

  it 'fails every example in the group, nested groups included', {
    expect(outcome()<result>.failed).to.be(2);
  }

  it 'runs no example body and no nested before-all hook, and still runs the after-all hook', {
    outcome();
    expect(log()).to.eq(['after-all']);
  }
}
