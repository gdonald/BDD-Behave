use BDD::Behave;

my $root    = $?FILE.IO.parent.parent.parent;
my $bin     = $root.add('bin/behave');
my $fixture = $root.add('t/fixtures/profile-fixture-spec.raku');

sub run-behave(*@args) {
  my $proc = run('raku', '-Ilib', $bin.absolute, |@args, :out, :err);
  my $out = $proc.out.slurp(:close);
  my $err = $proc.err.slurp(:close);
  %( :exit($proc.exitcode), :$out, :$err );
}

sub strip-ansi(Str $s --> Str) {
  $s.subst(/\e '[' \d+ 'm'/, '', :g);
}

describe 'bin/behave --profile', {
  it 'does not print a profile section without --profile', {
    my %r = run-behave($fixture.absolute);
    expect(%r<exit>).to.be(0);
    expect(strip-ansi(%r<out>).contains('slowest example')).to.be-falsy;
  }

  it 'prints a profile section with --profile (default N=10)', {
    my %r = run-behave('--profile', $fixture.absolute);
    expect(%r<exit>).to.be(0);
    my $out = strip-ansi(%r<out>);
    expect($out.contains('slowest example')).to.be-truthy;
    expect($out.contains('c slow example')).to.be-truthy;
  }

  it 'caps the section at N entries with --profile=N', {
    my %r = run-behave('--profile=2', $fixture.absolute);
    expect(%r<exit>).to.be(0);
    my $out = strip-ansi(%r<out>);
    expect($out.contains('Top 2 slowest examples')).to.be-truthy;
    expect($out.contains('c slow example')).to.be-truthy;
    expect($out.contains('b medium example')).to.be-truthy;
  }

  it 'rejects --profile=0 with a non-zero exit code', {
    my %r = run-behave('--profile=0', $fixture.absolute);
    expect(%r<exit>).to.not.be(0);
    expect(%r<err>.contains('--profile=N requires a positive integer')).to.be-truthy;
  }

  it 'rejects --profile=abc with a non-zero exit code', {
    my %r = run-behave('--profile=abc', $fixture.absolute);
    expect(%r<exit>).to.not.be(0);
    expect(%r<err>.contains('--profile=N requires a positive integer')).to.be-truthy;
  }
}

describe 'bin/behave --slow-threshold', {
  it 'does not print SLOW lines without --slow-threshold', {
    my %r = run-behave($fixture.absolute);
    expect(%r<exit>).to.be(0);
    expect(strip-ansi(%r<out>).contains('SLOW')).to.be-falsy;
  }

  it 'prints SLOW for examples at or above the threshold (--slow-threshold=0.01)', {
    my %r = run-behave('--format=tree', '--slow-threshold=0.01', $fixture.absolute);
    expect(%r<exit>).to.be(0);
    my $out = strip-ansi(%r<out>);
    expect($out.contains('SLOW')).to.be-truthy;
    expect($out.contains('threshold 0.010s')).to.be-truthy;
  }

  it 'does not print SLOW when the threshold is higher than every example', {
    my %r = run-behave('--slow-threshold=10', $fixture.absolute);
    expect(%r<exit>).to.be(0);
    expect(strip-ansi(%r<out>).contains('SLOW')).to.be-falsy;
  }

  it 'rejects --slow-threshold=0 with a non-zero exit code', {
    my %r = run-behave('--slow-threshold=0', $fixture.absolute);
    expect(%r<exit>).to.not.be(0);
    expect(%r<err>.contains('--slow-threshold requires a positive number')).to.be-truthy;
  }

  it 'rejects --slow-threshold=abc with a non-zero exit code', {
    my %r = run-behave('--slow-threshold=abc', $fixture.absolute);
    expect(%r<exit>).to.not.be(0);
    expect(%r<err>.contains('--slow-threshold requires a positive number')).to.be-truthy;
  }

  it 'accepts the space-separated form: --slow-threshold 0.01', {
    my %r = run-behave('--format=tree', '--slow-threshold', '0.01', $fixture.absolute);
    expect(%r<exit>).to.be(0);
    expect(strip-ansi(%r<out>).contains('SLOW')).to.be-truthy;
  }
}
