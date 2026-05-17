use BDD::Behave;

my $root    = $?FILE.IO.parent.parent.parent;
my $bin     = $root.add('bin/behave');
my $fixture = $root.add('t/fixtures/memory-fixture-spec.raku');

sub run-behave(*@args) {
  my $proc = run('raku', '-Ilib', $bin.absolute, |@args, :out, :err);
  my $out = $proc.out.slurp(:close);
  my $err = $proc.err.slurp(:close);
  %( :exit($proc.exitcode), :$out, :$err );
}

sub strip-ansi(Str $s --> Str) {
  $s.subst(/\e '[' \d+ 'm'/, '', :g);
}

describe 'bin/behave --memory-profile', {
  it 'does not print a memory profile section without --memory-profile', {
    my %r = run-behave($fixture.absolute);
    expect(%r<exit>).to.be(0);
    expect(strip-ansi(%r<out>).contains('memory-heaviest')).to.be-falsy;
  }

  it 'prints a memory profile section with --memory-profile (default N=10)', {
    my %r = run-behave('--memory-profile', $fixture.absolute);
    expect(%r<exit>).to.be(0);
    my $out = strip-ansi(%r<out>);
    expect($out.contains('memory-heaviest')).to.be-truthy;
  }

  it 'caps the section at N entries with --memory-profile=N', {
    my %r = run-behave('--memory-profile=2', $fixture.absolute);
    expect(%r<exit>).to.be(0);
    my $out = strip-ansi(%r<out>);
    expect($out.contains('Top 2 memory-heaviest examples')).to.be-truthy;
  }

  it 'rejects --memory-profile=0 with a non-zero exit code', {
    my %r = run-behave('--memory-profile=0', $fixture.absolute);
    expect(%r<exit>).to.not.be(0);
    expect(%r<err>.contains('--memory-profile=N requires a positive integer')).to.be-truthy;
  }

  it 'rejects --memory-profile=abc with a non-zero exit code', {
    my %r = run-behave('--memory-profile=abc', $fixture.absolute);
    expect(%r<exit>).to.not.be(0);
    expect(%r<err>.contains('--memory-profile=N requires a positive integer')).to.be-truthy;
  }
}

describe 'bin/behave --memory-threshold', {
  it 'does not print MEMORY lines without --memory-threshold', {
    my %r = run-behave($fixture.absolute);
    expect(%r<exit>).to.be(0);
    expect(strip-ansi(%r<out>).contains('MEMORY')).to.be-falsy;
  }

  it 'prints MEMORY for examples at or above the threshold', {
    my %r = run-behave('--format=tree', '--memory-threshold=1', $fixture.absolute);
    expect(%r<exit>).to.be(0);
    my $out = strip-ansi(%r<out>);
    expect($out.contains('MEMORY')).to.be-truthy;
    expect($out.contains('threshold 1 KB')).to.be-truthy;
  }

  it 'does not print MEMORY when the threshold is well above every delta', {
    my %r = run-behave('--memory-threshold=10000000', $fixture.absolute);
    expect(%r<exit>).to.be(0);
    expect(strip-ansi(%r<out>).contains('MEMORY')).to.be-falsy;
  }

  it 'rejects --memory-threshold=0 with a non-zero exit code', {
    my %r = run-behave('--memory-threshold=0', $fixture.absolute);
    expect(%r<exit>).to.not.be(0);
    expect(%r<err>.contains('--memory-threshold requires a positive integer')).to.be-truthy;
  }

  it 'rejects --memory-threshold=abc with a non-zero exit code', {
    my %r = run-behave('--memory-threshold=abc', $fixture.absolute);
    expect(%r<exit>).to.not.be(0);
    expect(%r<err>.contains('--memory-threshold requires a positive integer')).to.be-truthy;
  }

  it 'accepts the space-separated form: --memory-threshold 1', {
    my %r = run-behave('--format=tree', '--memory-threshold', '1', $fixture.absolute);
    expect(%r<exit>).to.be(0);
    expect(strip-ansi(%r<out>).contains('MEMORY')).to.be-truthy;
  }
}
