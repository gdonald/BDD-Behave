use BDD::Behave;

my $root = $?FILE.IO.parent.parent.parent;
my $bin  = $root.add('bin/behave');

# Use a small, well-behaved fixture so the CLI runs are fast.
my $fixture = $root.add('specs/expectations/be-between-spec.raku');

# A fixture with a deliberate failure, for the failure-shows-seed path.
my $failing = $root.add('t/fixtures/failing-fixture-spec.raku');

sub run-behave(*@args) {
  my $proc = run('raku', '-Ilib', $bin.absolute, |@args, :out, :err);
  my $out = $proc.out.slurp(:close);
  my $err = $proc.err.slurp(:close);
  %( :exit($proc.exitcode), :$out, :$err );
}

describe 'bin/behave --order and --seed', {
  it 'omits the seed line on a passing run by default', {
    my %r = run-behave($fixture.absolute);
    expect(%r<exit>).to.be(0);
    expect(%r<out>.contains('Randomized with seed')).to.be-falsy;
  }

  it 'prints "Randomized with seed N" on a passing run with --show-seed', {
    my %r = run-behave('--show-seed', $fixture.absolute);
    expect(%r<exit>).to.be(0);
    expect(%r<out>).to.match(/'Randomized with seed' \s+ \d+/);
  }

  it 'prints the seed on a failing run without --show-seed', {
    my %r = run-behave('--seed', '424242', $failing.absolute);
    expect(%r<exit>).to.not.be(0);
    expect(%r<out>).to.include('Randomized with seed 424242');
  }

  it 'omits the seed line when --order=defined is passed', {
    my %r = run-behave('--order', 'defined', '--show-seed', $fixture.absolute);
    expect(%r<exit>).to.be(0);
    expect(%r<out>.contains('Randomized with seed')).to.be-falsy;
  }

  it 'echoes the supplied --seed value with --show-seed', {
    my %r = run-behave('--seed', '424242', '--show-seed', $fixture.absolute);
    expect(%r<exit>).to.be(0);
    expect(%r<out>).to.include('Randomized with seed 424242');
  }

  it 'rejects an invalid --order value with a non-zero exit code', {
    my %r = run-behave('--order', 'sideways', $fixture.absolute);
    expect(%r<exit>).to.not.be(0);
    expect(%r<err>.contains("--order must be 'random' or 'defined'")).to.be-truthy;
  }

  it '--order=random with --seed produces a deterministic run twice', {
    my %a = run-behave('--seed', '777', $fixture.absolute);
    my %b = run-behave('--seed', '777', $fixture.absolute);

    # Strip the seed announcement line so we can compare the example order.
    my $strip = sub ($text) {
      $text.lines.grep({ !.contains('Randomized with seed') }).join("\n");
    };
    expect($strip(%a<out>)).to.eq($strip(%b<out>));
  }
}
