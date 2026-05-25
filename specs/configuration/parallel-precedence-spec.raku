use BDD::Behave;

my $root    = $?FILE.IO.parent.parent.parent;
my $lib     = $root.add('lib');
my $bin     = $root.add('bin/behave');
my $fixture = $root.add('t/fixtures/parallel/config-detect-fixture-spec.raku');

sub make-tmp-config(Str $body --> IO::Path) {
  my $path = $*TMPDIR.add("behave-parallel-precedence-spec-{$*PID}-{(now * 1e6).Int}.behave");
  $path.spurt($body);
  $path;
}

sub make-detect-path(--> IO::Path) {
  my $p = $*TMPDIR.add("behave-parallel-detect-spec-{$*PID}-{(now * 1e6).Int}");
  $p.unlink if $p.e;
  $p;
}

sub run-behave(:%env-extra, *@args) {
  my %env = |%*ENV;
  %env<BEHAVE_DISABLE_CONFIG> = '1';
  %env<BEHAVE_WORKER_INDEX>:delete;
  %env<BEHAVE_WORKER_COUNT>:delete;
  for %env-extra.kv -> $k, $v { %env{$k} = $v }
  my $proc = Proc::Async.new('raku', "-I{$lib.absolute}", $bin.absolute, |@args, :w);
  my $out = '';
  my $err = '';
  $proc.stdout.tap(-> $c { $out ~= $c });
  $proc.stderr.tap(-> $c { $err ~= $c });
  my $done = $proc.start(:ENV(%env));
  $proc.close-stdin;
  my $result = await $done;
  %( :exit($result.exitcode), :$out, :$err );
}

describe 'parallel config precedence', {
  it 'runs serially by default when no --parallel or config setting is present', {
    my $detect = make-detect-path;
    my %r = run-behave(
      :env-extra(%(BEHAVE_PARALLEL_DETECT => $detect.absolute)),
      '--order', 'defined',
      $fixture.absolute,
    );
    my $observed = $detect.slurp;
    $detect.unlink if $detect.e;

    expect(%r<exit>).to.be(0);
    expect($observed).to.be('serial');
  }

  it 'honors parallel = N from a config file', {
    my $detect = make-detect-path;
    my $cfg = make-tmp-config(q:to/CONFIG/);
      use BDD::Behave::Configuration;
      configure-behave -> $c { $c.parallel = 2 };
      CONFIG

    my %r = run-behave(
      :env-extra(%(BEHAVE_PARALLEL_DETECT => $detect.absolute)),
      '--config', $cfg.absolute,
      '--order', 'defined',
      $fixture.absolute,
    );
    my $observed = $detect.slurp;
    $detect.unlink if $detect.e;
    $cfg.unlink if $cfg.e;

    expect(%r<exit>).to.be(0);
    expect($observed).to.be('2');
  }

  it 'CLI --parallel N overrides parallel = M from a config file', {
    my $detect = make-detect-path;
    my $cfg = make-tmp-config(q:to/CONFIG/);
      use BDD::Behave::Configuration;
      configure-behave -> $c { $c.parallel = 2 };
      CONFIG

    my %r = run-behave(
      :env-extra(%(BEHAVE_PARALLEL_DETECT => $detect.absolute)),
      '--config', $cfg.absolute,
      '--parallel', '3',
      '--order', 'defined',
      $fixture.absolute,
    );
    my $observed = $detect.slurp;
    $detect.unlink if $detect.e;
    $cfg.unlink if $cfg.e;

    expect(%r<exit>).to.be(0);
    expect($observed).to.be('3');
  }

  it 'preserves --parallel 1 as a real parallel run with one worker', {
    my $detect = make-detect-path;
    my %r = run-behave(
      :env-extra(%(BEHAVE_PARALLEL_DETECT => $detect.absolute)),
      '--parallel', '1',
      '--order', 'defined',
      $fixture.absolute,
    );
    my $observed = $detect.slurp;
    $detect.unlink if $detect.e;

    expect(%r<exit>).to.be(0);
    expect($observed).to.be('1');
  }
}
