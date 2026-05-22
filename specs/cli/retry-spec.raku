use BDD::Behave;

my $root    = $?FILE.IO.parent.parent.parent;
my $bin     = $root.add('bin/behave');
my $passing = $root.add('specs/expectations/be-between-spec.raku');
my $flaky   = $root.add('t/fixtures/retry-pass-on-third-fixture-spec.raku');
my $mixed   = $root.add('t/fixtures/retry-mixed-fixture-spec.raku');

sub run-behave-with-attempts(@args, Str :$attempts-file) {
  my %env = |%*ENV;
  %env<BEHAVE_RETRY_ATTEMPTS_FILE> = $attempts-file if $attempts-file.defined;
  my $proc = run('raku', '-Ilib', $bin.absolute, |@args, :out, :err, :env(%env));
  my $out = $proc.out.slurp(:close);
  my $err = $proc.err.slurp(:close);
  %( :exit($proc.exitcode), :$out, :$err );
}

describe 'bin/behave --retry', {
  it 'rejects --retry with no value', {
    my $proc = run('raku', '-Ilib', $bin.absolute, '--retry', :out, :err);
    my $err = $proc.err.slurp(:close);
    $proc.out.slurp(:close);
    expect($proc.exitcode).to.not.be(0);
    expect($err.contains('--retry requires a value')).to.be-truthy;
  }

  it 'rejects --retry=abc with a clear error', {
    my %r = run-behave-with-attempts(['--retry=abc', $passing.absolute]);
    expect(%r<exit>).to.not.be(0);
    expect(%r<err>.contains('--retry=N requires a non-negative integer')).to.be-truthy;
  }

  it 'accepts --retry=0 and runs each example exactly once', {
    my $tmp = $*TMPDIR.add("behave-retry-{$*PID}-zero.txt");
    $tmp.unlink if $tmp.e;
    LEAVE { $tmp.unlink if $tmp.e }
    my %r = run-behave-with-attempts(
      ['--retry=0', '--order', 'defined', $flaky.absolute],
      :attempts-file($tmp.absolute),
    );
    expect(%r<exit>).to.not.be(0);
    expect(%r<out>.contains('1 failed')).to.be-truthy;
    expect($tmp.slurp.trim.Int).to.be(1);
  }

  it 'with --retry 2 succeeds when an example passes on the third attempt', {
    my $tmp = $*TMPDIR.add("behave-retry-{$*PID}-three.txt");
    $tmp.unlink if $tmp.e;
    LEAVE { $tmp.unlink if $tmp.e }
    my %r = run-behave-with-attempts(
      ['--retry', '2', '--order', 'defined', $flaky.absolute],
      :attempts-file($tmp.absolute),
    );
    expect(%r<exit>).to.be(0);
    expect(%r<out>.contains('1 passed')).to.be-truthy;
    expect($tmp.slurp.trim.Int).to.be(3);
  }

  it 'with --retry 1 still fails when three attempts would be needed', {
    my $tmp = $*TMPDIR.add("behave-retry-{$*PID}-one.txt");
    $tmp.unlink if $tmp.e;
    LEAVE { $tmp.unlink if $tmp.e }
    my %r = run-behave-with-attempts(
      ['--retry=1', '--order', 'defined', $flaky.absolute],
      :attempts-file($tmp.absolute),
    );
    expect(%r<exit>).to.not.be(0);
    expect(%r<out>.contains('1 failed')).to.be-truthy;
    expect($tmp.slurp.trim.Int).to.be(2);
  }

  it 'prints a Retried examples summary section when retries occur', {
    my $tmp = $*TMPDIR.add("behave-retry-{$*PID}-summary.txt");
    $tmp.unlink if $tmp.e;
    LEAVE { $tmp.unlink if $tmp.e }
    my %r = run-behave-with-attempts(
      ['--retry', '2', '--order', 'defined', $flaky.absolute],
      :attempts-file($tmp.absolute),
    );
    expect(%r<out>.contains('Retried 1 example:')).to.be-truthy;
    expect(%r<out>.contains('[PASS]')).to.be-truthy;
    expect(%r<out>.contains('3/3 attempts')).to.be-truthy;
  }

  it 'does not print the retry section when no retries happened', {
    my %r = run-behave-with-attempts(['--retry', '2', $passing.absolute]);
    expect(%r<exit>).to.be(0);
    expect(%r<out>.contains('Retried')).to.be-falsy;
  }

  it 'honors per-example :retry metadata', {
    my $tmp = $*TMPDIR.add("behave-retry-{$*PID}-meta.txt");
    $tmp.unlink if $tmp.e;
    LEAVE { $tmp.unlink if $tmp.e }
    my %r = run-behave-with-attempts(
      ['--order', 'defined', $mixed.absolute],
      :attempts-file($tmp.absolute),
    );
    expect(%r<out>.contains('1 failed')).to.be-truthy;
    expect(%r<out>.contains('2 passed')).to.be-truthy;
    expect(%r<out>.contains('Retried 2 examples:')).to.be-truthy;
    expect(%r<out>.contains('2/3 attempts')).to.be-truthy;
    expect(%r<out>.contains('2/2 attempts')).to.be-truthy;
  }
}
