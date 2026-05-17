use BDD::Behave;
use BDD::Behave::Runner;
use BDD::Behave::SpecTree;

constant Suite        = BDD::Behave::SpecTree::Suite;
constant ExampleGroup = BDD::Behave::SpecTree::ExampleGroup;
constant Example      = BDD::Behave::SpecTree::Example;

sub strip-ansi(Str $s --> Str) {
  $s.subst(/\e '[' \d+ 'm'/, '', :g);
}

sub capture-run($suite, *%args) {
  my $tmp = $*TMPDIR.add("behave-memory-spec-{$*PID}-{(now * 1e6).Int}.out");
  my $runner;
  my $result;
  {
    my $fh = $tmp.open(:w);
    my $*OUT = $fh;
    $runner = BDD::Behave::Runner::Runner.new(|%args);
    $result = $runner.run($suite);
    $fh.close;
  }
  my $captured = $tmp.slurp;
  $tmp.unlink;
  %( runner => $runner, result => $result, out => strip-ansi($captured) );
}

sub build-suite(@examples, :$file = 'synthetic'.IO) {
  my $suite = Suite.create(:description('memory'), :$file, :line(1));
  my $group = ExampleGroup.new(:description('g'), :$file, :line(1));
  $suite.add-group($group);
  $group.add-example($_) for @examples;
  $suite;
}

describe 'Example memory slots', {
  it 'starts with memory-before, memory-after, memory-delta undefined', {
    my $ex = Example.new(
      :description('inert'),
      :file('synthetic'.IO), :line(10),
      :block({ True }),
    );
    expect($ex.memory-before.defined).to.be-falsy;
    expect($ex.memory-after.defined).to.be-falsy;
    expect($ex.memory-delta.defined).to.be-falsy;
  }

  it 'leaves the slots undefined when measurement is disabled', {
    my $ex = Example.new(
      :description('untracked'),
      :file('f'.IO), :line(11),
      :block({ True }),
    );
    capture-run(build-suite([$ex]));

    expect($ex.memory-before.defined).to.be-falsy;
    expect($ex.memory-after.defined).to.be-falsy;
    expect($ex.memory-delta.defined).to.be-falsy;
  }

  it 'records Int memory values when memory-profile is on', {
    my $ex = Example.new(
      :description('tracked'),
      :file('f'.IO), :line(12),
      :block({ True }),
    );
    capture-run(build-suite([$ex]), :memory-profile(True));

    expect($ex.memory-before ~~ Int).to.be-truthy;
    expect($ex.memory-after ~~ Int).to.be-truthy;
    expect($ex.memory-delta ~~ Int).to.be-truthy;
  }

  it 'sets memory-delta to memory-after minus memory-before', {
    my $ex = Example.new(
      :description('delta'),
      :file('f'.IO), :line(13),
      :block({ True }),
    );
    capture-run(build-suite([$ex]), :memory-profile(True));

    expect($ex.memory-delta).to.be($ex.memory-after - $ex.memory-before);
  }

  it 'still records memory for a failing example', {
    my $ex = Example.new(
      :description('boom'),
      :file('f'.IO), :line(14),
      :block({ die 'intentional' }),
    );
    capture-run(build-suite([$ex]), :memory-profile(True));

    expect($ex.memory-before.defined).to.be-truthy;
    expect($ex.memory-after.defined).to.be-truthy;
    expect($ex.memory-delta.defined).to.be-truthy;
  }

  it 'leaves the slots undefined for a pending example', {
    my $ex = Example.new(
      :description('todo'),
      :file('f'.IO), :line(15),
      :block({ True }),
    );
    $ex.mark-pending;
    capture-run(build-suite([$ex]), :memory-profile(True));

    expect($ex.memory-before.defined).to.be-falsy;
    expect($ex.memory-after.defined).to.be-falsy;
    expect($ex.memory-delta.defined).to.be-falsy;
  }

  it 'leaves the slots undefined for a skipped example', {
    my $ex = Example.new(
      :description('skipped'),
      :file('f'.IO), :line(16),
      :block({ die 'should not run' }),
    );
    $ex.set-metadata(:skipped(True));
    capture-run(build-suite([$ex]), :memory-profile(True));

    expect($ex.memory-before.defined).to.be-falsy;
    expect($ex.memory-after.defined).to.be-falsy;
    expect($ex.memory-delta.defined).to.be-falsy;
  }
}

describe 'Runner.memory-records', {
  it 'is empty when measurement is disabled', {
    my $a = Example.new(:description('a'), :file('f'.IO), :line(20),
                        :block({ True }));
    my %r = capture-run(build-suite([$a]));
    expect(%r<runner>.memory-records.elems).to.be(0);
  }

  it 'records one entry per executed example when measurement is on', {
    my $a = Example.new(:description('a'), :file('f'.IO), :line(21),
                        :block({ True }));
    my $b = Example.new(:description('b'), :file('f'.IO), :line(22),
                        :block({ True }));
    my %r = capture-run(build-suite([$a, $b]),
                        :memory-profile(True), :order<defined>);
    expect(%r<runner>.memory-records.elems).to.be(2);
  }

  it 'omits pending and skipped examples from memory-records', {
    my $pending = Example.new(:description('p'), :file('f'.IO), :line(23),
                              :block({ True }));
    $pending.mark-pending;

    my $skipped = Example.new(:description('s'), :file('f'.IO), :line(24),
                              :block({ die 'no' }));
    $skipped.set-metadata(:skipped(True));

    my $passing = Example.new(:description('q'), :file('f'.IO), :line(25),
                              :block({ True }));

    my %r = capture-run(build-suite([$pending, $skipped, $passing]),
                        :memory-profile(True), :order<defined>);

    expect(%r<runner>.memory-records.elems).to.be(1);
    expect(%r<runner>.memory-records[0]<description>.contains('q')).to.be-truthy;
  }

  it 'records before/after/delta on each record', {
    my $a = Example.new(:description('a'), :file('f'.IO), :line(26),
                        :block({ True }));
    my %r = capture-run(build-suite([$a]), :memory-profile(True));

    my %rec = %r<runner>.memory-records[0];
    expect(%rec<before> ~~ Int).to.be-truthy;
    expect(%rec<after>  ~~ Int).to.be-truthy;
    expect(%rec<delta>  ~~ Int).to.be-truthy;
    expect(%rec<delta>).to.be(%rec<after> - %rec<before>);
  }
}

describe '--memory-profile / memory-profile-limit', {
  it 'is disabled by default and prints no memory profile section', {
    my $ex = Example.new(:description('x'), :file('f'.IO), :line(30),
                         :block({ True }));
    my %r = capture-run(build-suite([$ex]));
    expect(%r<out>.contains('memory-heaviest')).to.be-falsy;
  }

  it 'prints a "Top N memory-heaviest" section when memory-profile-limit > 0', {
    my $a = Example.new(:description('alpha'), :file('f'.IO), :line(31),
                        :block({ True }));
    my $b = Example.new(:description('beta'), :file('f'.IO), :line(32),
                        :block({ True }));
    my %r = capture-run(build-suite([$a, $b]),
                        :memory-profile-limit(2), :order<defined>);

    expect(%r<out>.contains('Top 2 memory-heaviest examples')).to.be-truthy;
    expect(%r<out>.contains('alpha')).to.be-truthy;
    expect(%r<out>.contains('beta')).to.be-truthy;
  }

  it 'singularizes the heading when only one example was measured', {
    my $only = Example.new(:description('lonely'), :file('f'.IO), :line(33),
                           :block({ True }));
    my %r = capture-run(build-suite([$only]), :memory-profile-limit(5));

    expect(%r<out>.contains('Top 1 memory-heaviest example ')).to.be-truthy;
  }

  it 'rejects a negative memory-profile-limit', {
    expect({
      BDD::Behave::Runner::Runner.new(:memory-profile-limit(-1));
    }).to.raise-error(/'memory-profile-limit'/);
  }
}

describe '--memory-threshold', {
  it 'is disabled by default and prints no MEMORY lines', {
    my $ex = Example.new(:description('q'), :file('f'.IO), :line(40),
                         :block({ True }));
    my %r = capture-run(build-suite([$ex]));
    expect(%r<out>.contains('MEMORY')).to.be-falsy;
  }

  it 'prints a MEMORY line for examples at or above the threshold', {
    my $ex = Example.new(
      :description('big'),
      :file('f'.IO), :line(41),
      :block({ my @data = (1 .. 100_000).map(*.Str); @data.elems }),
    );
    my %r = capture-run(build-suite([$ex]), :memory-threshold(1));

    expect(%r<out>.contains('MEMORY')).to.be-truthy;
    expect(%r<out>.contains('threshold 1 KB')).to.be-truthy;
  }

  it 'does not print MEMORY when threshold is well above any delta', {
    my $ex = Example.new(:description('small'), :file('f'.IO), :line(42),
                         :block({ True }));
    my %r = capture-run(build-suite([$ex]), :memory-threshold(10_000_000));
    expect(%r<out>.contains('MEMORY')).to.be-falsy;
  }

  it 'rejects a negative memory-threshold', {
    expect({
      BDD::Behave::Runner::Runner.new(:memory-threshold(-1));
    }).to.raise-error(/'memory-threshold'/);
  }
}

describe 'memory-measurement-enabled', {
  it 'is false by default', {
    my $runner = BDD::Behave::Runner::Runner.new;
    expect($runner.memory-measurement-enabled).to.be-falsy;
  }

  it 'is true when memory-profile is True', {
    my $runner = BDD::Behave::Runner::Runner.new(:memory-profile(True));
    expect($runner.memory-measurement-enabled).to.be-truthy;
  }

  it 'is true when memory-profile-limit > 0', {
    my $runner = BDD::Behave::Runner::Runner.new(:memory-profile-limit(3));
    expect($runner.memory-measurement-enabled).to.be-truthy;
  }

  it 'is true when memory-threshold > 0', {
    my $runner = BDD::Behave::Runner::Runner.new(:memory-threshold(100));
    expect($runner.memory-measurement-enabled).to.be-truthy;
  }
}
