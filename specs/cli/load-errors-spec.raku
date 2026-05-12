use BDD::Behave;

my $root    = $?FILE.IO.parent.parent.parent;
my $bin     = $root.add('bin/behave');
my $broken  = $root.add('t/fixtures/broken-fixture-spec.raku');
my $passing = $root.add('specs/expectations/be-between-spec.raku');

sub run-behave(*@args) {
  my $proc = run('raku', '-Ilib', $bin.absolute, |@args, :out, :err);
  my $out = $proc.out.slurp(:close);
  my $err = $proc.err.slurp(:close);
  %( :exit($proc.exitcode), :$out, :$err );
}

describe 'bin/behave load-error handling', {
  it 'exits non-zero when a spec file fails to compile', {
    my %r = run-behave($broken.absolute);
    expect(%r<exit>).to.not.be(0);
  }

  it 'prints the load error to stderr', {
    my %r = run-behave($broken.absolute);
    expect(%r<err>.contains('Error: Could not load') ?? 1 !! 0).to.be(1);
    expect(%r<err>.contains('broken-fixture-spec.raku') ?? 1 !! 0).to.be(1);
  }

  it 'surfaces load errors in the run summary on stdout', {
    my %r = run-behave($broken.absolute);
    expect(%r<out>.contains('Load errors') ?? 1 !! 0).to.be(1);
    expect(%r<out>.contains('broken-fixture-spec.raku') ?? 1 !! 0).to.be(1);
  }

  it 'still exits 0 for a passing spec file', {
    my %r = run-behave($passing.absolute);
    expect(%r<exit>).to.be(0);
    expect(%r<err>.contains('Could not load') ?? 1 !! 0).to.be(0);
  }

  it 'mixed batch exits non-zero but still runs the good file', {
    my %r = run-behave($passing.absolute, $broken.absolute);
    expect(%r<exit>).to.not.be(0);
    expect(%r<out>.contains('passed') ?? 1 !! 0).to.be(1);
  }
}
