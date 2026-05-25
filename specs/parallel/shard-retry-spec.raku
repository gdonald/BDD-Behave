use BDD::Behave;

my $root   = $?FILE.IO.parent.parent.parent;
my $lib    = $root.add('lib');
my $bin    = $root.add('bin/behave');
my $crash  = $root.add('t/fixtures/parallel/shard-crash-fixture-spec.raku');
my $always = $root.add('t/fixtures/parallel/shard-always-crash-fixture-spec.raku');

sub strip-ansi(Str $s --> Str) {
  $s.subst(/ \e '[' <[0..9;]>* 'm' /, '', :g);
}

sub run-behave(:%env-extra, *@args) {
  my %env = |%*ENV;
  %env<BEHAVE_DISABLE_CONFIG> = '1';
  %env<BEHAVE_WORKER_INDEX>:delete;
  %env<BEHAVE_WORKER_COUNT>:delete;
  for %env-extra.kv -> $k, $v { %env{$k} = $v }
  my $proc = Proc::Async.new(
    'raku', "-I{$lib.absolute}", $bin.absolute, |@args, :w,
  );
  my $out = '';
  my $err = '';
  $proc.stdout.tap(-> $c { $out ~= $c });
  $proc.stderr.tap(-> $c { $err ~= $c });
  my $done = $proc.start(:ENV(%env));
  $proc.close-stdin;
  my $result = await $done;
  %( :exit($result.exitcode), :$out, :$err );
}

describe '--parallel-retry on worker crash', {
  it 'recovers cleanly when a shard crash falls within the retry budget', {
    my $marker = $*TMPDIR.add("behave-shard-retry-spec-{$*PID}-{(now * 1e6).Int}");
    $marker.unlink if $marker.e;

    my %r = run-behave(
      :env-extra(%(BEHAVE_CRASH_MARKER => $marker.absolute)),
      '--parallel', '1', '--parallel-retry', '2',
      '--order', 'defined',
      $crash.absolute,
    );
    $marker.unlink if $marker.e;

    expect(%r<exit>).to.be(0);
  }

  it 'reports the shard retry in the summary section', {
    my $marker = $*TMPDIR.add("behave-shard-retry-spec-summary-{$*PID}-{(now * 1e6).Int}");
    $marker.unlink if $marker.e;

    my %r = run-behave(
      :env-extra(%(BEHAVE_CRASH_MARKER => $marker.absolute)),
      '--parallel', '1', '--parallel-retry', '2',
      '--order', 'defined',
      $crash.absolute,
    );
    $marker.unlink if $marker.e;

    my $clean = strip-ansi(%r<out>);
    expect($clean).to.include('Shard retries: 1');
    expect($clean).to.include('recovered');
    expect($clean).to.include('137');
  }

  it 'treats a crash as fatal when --parallel-retry is absent', {
    my $marker = $*TMPDIR.add("behave-shard-retry-spec-noretry-{$*PID}-{(now * 1e6).Int}");
    $marker.unlink if $marker.e;

    my %r = run-behave(
      :env-extra(%(BEHAVE_CRASH_MARKER => $marker.absolute)),
      '--parallel', '1',
      '--order', 'defined',
      $crash.absolute,
    );
    $marker.unlink if $marker.e;

    expect(%r<exit>).to.be(1);
    my $clean = strip-ansi(%r<out> ~ %r<err>);
    expect($clean).not.to.include('Shard retries:');
  }

  it 'reports a crashed shard when the retry budget is exhausted', {
    my %r = run-behave(
      '--parallel', '1', '--parallel-retry', '1',
      '--order', 'defined',
      $always.absolute,
    );

    expect(%r<exit>).to.be(1);
    my $clean = strip-ansi(%r<out> ~ %r<err>);
    expect($clean).to.include('Shard retries: 1');
    expect($clean).to.include('crashed');
  }
}
