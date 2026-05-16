use BDD::Behave;
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
  $result;
}

sub build-suite(@examples) {
  my $suite = Suite.create(:description('timing'), :file('synthetic'.IO), :line(1));
  my $group = ExampleGroup.new(:description('g'), :file('synthetic'.IO), :line(1));
  $suite.add-group($group);
  $group.add-example($_) for @examples;
  $suite;
}

describe 'Example duration storage', {
  it 'starts with duration, started-at, finished-at all undefined', {
    my $ex = Example.new(
      :description('inert'),
      :file('synthetic'.IO), :line(10),
      :block({ True }),
    );
    expect($ex.duration.defined).to.be-falsy;
    expect($ex.started-at.defined).to.be-falsy;
    expect($ex.finished-at.defined).to.be-falsy;
  }

  it 'records a non-negative Real duration after running', {
    my $ex = Example.new(
      :description('quick'),
      :file('synthetic'.IO), :line(11),
      :block({ True }),
    );
    silent-run(build-suite([$ex]));

    expect($ex.duration.defined).to.be-truthy;
    expect($ex.duration ~~ Real).to.be-truthy;
    expect($ex.duration).to.be-greater-than-or-equal-to(0);
  }

  it 'records Instant values for started-at and finished-at', {
    my $ex = Example.new(
      :description('quick'),
      :file('synthetic'.IO), :line(12),
      :block({ True }),
    );
    silent-run(build-suite([$ex]));

    expect($ex.started-at ~~ Instant).to.be-truthy;
    expect($ex.finished-at ~~ Instant).to.be-truthy;
  }

  it 'records finished-at no earlier than started-at', {
    my $ex = Example.new(
      :description('quick'),
      :file('synthetic'.IO), :line(13),
      :block({ True }),
    );
    silent-run(build-suite([$ex]));

    expect($ex.finished-at >= $ex.started-at).to.be-truthy;
  }

  it 'records duration that matches finished-at minus started-at', {
    my $ex = Example.new(
      :description('quick'),
      :file('synthetic'.IO), :line(14),
      :block({ True }),
    );
    silent-run(build-suite([$ex]));

    my $delta = ($ex.finished-at - $ex.started-at).Real;
    expect(($ex.duration - $delta).abs < 1e-6).to.be-truthy;
  }

  it 'records a longer duration for an example that sleeps', {
    my $ex = Example.new(
      :description('slow'),
      :file('synthetic'.IO), :line(15),
      :block({ sleep 0.05 }),
    );
    silent-run(build-suite([$ex]));

    expect($ex.duration).to.be-greater-than-or-equal-to(0.04);
  }

  it 'still records duration for an example that fails', {
    my $ex = Example.new(
      :description('boom'),
      :file('synthetic'.IO), :line(16),
      :block({ die 'intentional failure' }),
    );
    silent-run(build-suite([$ex]));

    expect($ex.duration.defined).to.be-truthy;
    expect($ex.duration).to.be-greater-than-or-equal-to(0);
  }

  it 'leaves duration undefined for a pending example', {
    my $ex = Example.new(
      :description('todo'),
      :file('synthetic'.IO), :line(17),
      :block({ True }),
    );
    $ex.mark-pending;
    silent-run(build-suite([$ex]));

    expect($ex.duration.defined).to.be-falsy;
    expect($ex.started-at.defined).to.be-falsy;
  }

  it 'leaves duration undefined for a skipped example', {
    my $ex = Example.new(
      :description('skipped'),
      :file('synthetic'.IO), :line(18),
      :block({ die 'should not run' }),
    );
    $ex.set-metadata(:skipped(True));
    silent-run(build-suite([$ex]));

    expect($ex.duration.defined).to.be-falsy;
    expect($ex.started-at.defined).to.be-falsy;
  }

  it 'records independent durations for siblings in the same run', {
    my $fast = Example.new(
      :description('fast'),
      :file('synthetic'.IO), :line(19),
      :block({ True }),
    );
    my $slow = Example.new(
      :description('slow'),
      :file('synthetic'.IO), :line(20),
      :block({ sleep 0.03 }),
    );
    silent-run(build-suite([$fast, $slow]), :order<defined>);

    expect($fast.duration.defined).to.be-truthy;
    expect($slow.duration.defined).to.be-truthy;
    expect($slow.duration).to.be-greater-than-or-equal-to($fast.duration);
  }
}
