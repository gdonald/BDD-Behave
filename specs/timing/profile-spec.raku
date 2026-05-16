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
  my $tmp = $*TMPDIR.add("behave-profile-spec-{$*PID}-{(now * 1e6).Int}.out");
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
  my $suite = Suite.create(:description('profile'), :$file, :line(1));
  my $group = ExampleGroup.new(:description('g'), :$file, :line(1));
  $suite.add-group($group);
  $group.add-example($_) for @examples;
  $suite;
}

describe 'Runner.timed-examples', {
  it 'records one entry per executed example', {
    my $a = Example.new(:description('a'), :file('f'.IO), :line(1), :block({ True }));
    my $b = Example.new(:description('b'), :file('f'.IO), :line(2), :block({ True }));
    my %r = capture-run(build-suite([$a, $b]), :order<defined>);

    expect(%r<runner>.timed-examples.elems).to.be(2);
  }

  it 'omits pending and skipped examples from timed-examples', {
    my $pending = Example.new(:description('p'), :file('f'.IO), :line(3), :block({ True }));
    $pending.mark-pending;

    my $skipped = Example.new(:description('s'), :file('f'.IO), :line(4), :block({ die 'no' }));
    $skipped.set-metadata(:skipped(True));

    my $passing = Example.new(:description('q'), :file('f'.IO), :line(5), :block({ True }));

    my %r = capture-run(build-suite([$pending, $skipped, $passing]), :order<defined>);

    expect(%r<runner>.timed-examples.elems).to.be(1);
    expect(%r<runner>.timed-examples[0]<description>.contains('q')).to.be-truthy;
  }

  it 'still records timings for failing examples', {
    my $boom = Example.new(:description('boom'), :file('f'.IO), :line(6),
                           :block({ die 'intentional' }));
    my %r = capture-run(build-suite([$boom]));

    expect(%r<runner>.timed-examples.elems).to.be(1);
    expect(%r<runner>.timed-examples[0]<duration>).to.be-greater-than-or-equal-to(0);
  }
}

describe '--profile / profile-limit', {
  it 'is disabled by default and prints no profile section', {
    my $ex = Example.new(:description('x'), :file('f'.IO), :line(7), :block({ True }));
    my %r = capture-run(build-suite([$ex]));

    expect(%r<out>.contains('slowest example')).to.be-falsy;
  }

  it 'prints a "Top N slowest" section when profile-limit > 0', {
    my $a = Example.new(:description('alpha'), :file('f'.IO), :line(8),
                        :block({ True }));
    my $b = Example.new(:description('beta'),  :file('f'.IO), :line(9),
                        :block({ sleep 0.05 }));
    my %r = capture-run(build-suite([$a, $b]), :profile-limit(2), :order<defined>);

    expect(%r<out>.contains('Top 2 slowest examples')).to.be-truthy;
    expect(%r<out>.contains('alpha')).to.be-truthy;
    expect(%r<out>.contains('beta')).to.be-truthy;
  }

  it 'orders the profile by duration (slowest first)', {
    my $fast = Example.new(:description('fast-here'), :file('f'.IO), :line(10),
                           :block({ True }));
    my $slow = Example.new(:description('slow-here'), :file('f'.IO), :line(11),
                           :block({ sleep 0.05 }));
    my %r = capture-run(build-suite([$fast, $slow]), :profile-limit(2), :order<defined>);

    my $header   = %r<out>.index('Top 2 slowest');
    my $slow-pos = %r<out>.index('slow-here', $header + 1);
    my $fast-pos = %r<out>.index('fast-here', $header + 1);
    expect($header.defined && $slow-pos.defined && $fast-pos.defined).to.be-truthy;
    expect($slow-pos < $fast-pos).to.be-truthy;
  }

  it 'caps the section at N entries when more examples exist', {
    my @examples = (^5).map: -> $i {
      Example.new(:description("ex-$i"), :file('f'.IO), :line(20 + $i),
                  :block({ True }));
    };
    my %r = capture-run(build-suite(@examples), :profile-limit(2), :order<defined>);

    expect(%r<out>.contains('Top 2 slowest examples')).to.be-truthy;
  }

  it 'singularizes the heading when only one example was timed', {
    my $only = Example.new(:description('lonely'), :file('f'.IO), :line(30),
                           :block({ True }));
    my %r = capture-run(build-suite([$only]), :profile-limit(5));

    expect(%r<out>.contains('Top 1 slowest example ')).to.be-truthy;
  }

  it 'rejects a negative profile-limit', {
    expect({
      BDD::Behave::Runner::Runner.new(:profile-limit(-1));
    }).to.raise-error(/'profile-limit'/);
  }
}

describe '--slow-threshold', {
  it 'is disabled by default and prints no SLOW lines', {
    my $ex = Example.new(:description('q'), :file('f'.IO), :line(40),
                         :block({ sleep 0.05 }));
    my %r = capture-run(build-suite([$ex]));

    expect(%r<out>.contains('SLOW')).to.be-falsy;
  }

  it 'prints a SLOW line for examples at or above the threshold', {
    my $slow = Example.new(:description('slow'), :file('f'.IO), :line(41),
                           :block({ sleep 0.05 }));
    my %r = capture-run(build-suite([$slow]), :slow-threshold(0.01));

    expect(%r<out>.contains('SLOW')).to.be-truthy;
    expect(%r<out>.contains('threshold 0.010s')).to.be-truthy;
  }

  it 'does not print SLOW for examples below the threshold', {
    my $fast = Example.new(:description('fast'), :file('f'.IO), :line(42),
                           :block({ True }));
    my %r = capture-run(build-suite([$fast]), :slow-threshold(5));

    expect(%r<out>.contains('SLOW')).to.be-falsy;
  }

  it 'prints SLOW for a slow but failing example', {
    my $slow-fail = Example.new(:description('boom'), :file('f'.IO), :line(43),
                                :block({ sleep 0.03; die 'fail' }));
    my %r = capture-run(build-suite([$slow-fail]), :slow-threshold(0.01));

    expect(%r<out>.contains('FAILURE')).to.be-truthy;
    expect(%r<out>.contains('SLOW')).to.be-truthy;
  }

  it 'rejects a negative slow-threshold', {
    expect({
      BDD::Behave::Runner::Runner.new(:slow-threshold(-0.5));
    }).to.raise-error(/'slow-threshold'/);
  }
}
