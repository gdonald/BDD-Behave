use BDD::Behave;
use BDD::Behave::Configuration;
use BDD::Behave::Runner;
use BDD::Behave::SpecTree;
use Test::Output;

constant Configuration = BDD::Behave::Configuration::Configuration;
constant Runner        = BDD::Behave::Runner::Runner;
constant Suite         = BDD::Behave::SpecTree::Suite;
constant ExampleGroup  = BDD::Behave::SpecTree::ExampleGroup;
constant Example       = BDD::Behave::SpecTree::Example;

# A hook that throws is reported on stderr and the run carries on. Each case
# builds its own suite and hands it to a second runner, so the outer run only
# sees what that inner run wrote.
sub suite-recording-into(@log --> List) {
  my $suite = Suite.create(:description('hooks'), :file('synthetic'.IO), :line(1));
  my $group = ExampleGroup.new(:description('a group'), :file('synthetic'.IO), :line(1));
  $suite.add-group($group);
  $group.add-example(
    Example.new(
      :description('an example'),
      :file('synthetic'.IO),
      :line(2),
      :block(sub { @log.push('example') }),
    ),
  );
  ($suite, $group);
}

sub run-quiet(Suite $suite, $config = Nil) {
  my $sink = open '/dev/null', :w;
  my $runner = Runner.new(:order<defined>, |($config.defined ?? (:$config) !! ()));
  {
    my $*OUT = $sink;
    $runner.run($suite);
  }
  $sink.close;
}

describe 'a group hook that throws', {
  sub stderr-of-run(@log --> Str) {
    my ($suite, $group) = suite-recording-into(@log);
    $group.add-hook('before-all', sub { die 'hook exploded' });
    stderr-from({ run-quiet($suite) });
  }

  it 'names the phase and the group on stderr', {
    my @log;
    expect(stderr-of-run(@log)).to.include('Hook before-all failed in a group');
  }

  it 'carries the message of the exception', {
    my @log;
    expect(stderr-of-run(@log)).to.include('hook exploded');
  }

  it 'still runs the example', {
    my @log;
    stderr-of-run(@log);
    expect(@log).to.eq(['example']);
  }
}

describe 'a config hook that throws', {
  sub stderr-of-run(@log --> Str) {
    my ($suite, $group) = suite-recording-into(@log);
    my $config = Configuration.new;
    $config.before-each(sub { die 'config hook exploded' });
    stderr-from({ run-quiet($suite, $config) });
  }

  it 'names the phase on stderr', {
    my @log;
    expect(stderr-of-run(@log)).to.include('Config before-each hook failed');
  }

  it 'carries the message of the exception', {
    my @log;
    expect(stderr-of-run(@log)).to.include('config hook exploded');
  }

  it 'still runs the example', {
    my @log;
    stderr-of-run(@log);
    expect(@log).to.eq(['example']);
  }
}
