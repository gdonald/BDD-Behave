use BDD::Behave;

my $root = $?FILE.IO.parent.parent.parent;
my $lib  = $root.add('lib');
my $bin  = $root.add('bin/behave');
my $fix  = $root.add('t/fixtures/benchmark-fixture-spec.raku');

sub strip-ansi(Str $s --> Str) {
  $s.subst(/ \e '[' <[0..9;]>* 'm' /, '', :g);
}

sub run-behave(*@args) {
  my %env = |%*ENV;
  %env<BEHAVE_DISABLE_CONFIG> = '1';
  my $proc = Proc::Async.new(
    'raku', "-I{$lib.absolute}", $bin.absolute, |@args, :w,
  );
  my $out = '';
  my $err = '';
  $proc.stdout.tap(-> $c { $out ~= $c });
  $proc.stderr.tap(-> $c { $err ~= $c });
  my $done = $proc.start(:%env);
  $proc.close-stdin;
  my $result = await $done;
  %( :exit($result.exitcode), :$out, :$err );
}

describe '--benchmark under --parallel', {
  it 'prints the Benchmarks section', {
    my %r = run-behave(
      '--parallel', '2', '--order', 'defined', '--benchmark',
      $fix.absolute,
    );
    my $clean = strip-ansi(%r<out>);

    expect($clean).to.include('Benchmarks (');
  }

  it 'aggregates measurements from every worker', {
    my %r = run-behave(
      '--parallel', '2', '--order', 'defined', '--benchmark',
      $fix.absolute,
    );
    my $clean = strip-ansi(%r<out>);

    expect($clean).to.include('label:sum');
    expect($clean).to.include('label:a');
    expect($clean).to.include('label:b');
  }

  it 'reports the aggregated measurement count', {
    my %r = run-behave(
      '--parallel', '2', '--order', 'defined', '--benchmark',
      $fix.absolute,
    );
    my $clean = strip-ansi(%r<out>);

    expect($clean).to.include('Benchmarks (3 measurements)');
  }
}

describe '--benchmark-save under --parallel', {
  it 'writes an aggregated baseline file', {
    my $baseline = $*TMPDIR.add("behave-bench-save-{$*PID}-{(now * 1e6).Int}.tsv");
    LEAVE { $baseline.unlink if $baseline.e }

    my %r = run-behave(
      '--parallel', '2', '--order', 'defined',
      '--benchmark-save=' ~ $baseline.absolute,
      $fix.absolute,
    );

    expect($baseline.e).to.be-truthy;

    my $body = $baseline.slurp;
    expect($body).to.include('measures a sum');
    expect($body).to.include('label:sum');
    expect($body).to.include('label:a');
    expect($body).to.include('label:b');
  }
}

describe '--benchmark-baseline under --parallel', {
  it 'compares the aggregated measurements against the baseline', {
    my $baseline = $*TMPDIR.add("behave-bench-base-{$*PID}-{(now * 1e6).Int}.tsv");
    LEAVE { $baseline.unlink if $baseline.e }

    $baseline.spurt: qq:to/EOF/;
    # behave-benchmark-baseline v1
    description\tkey\titerations\tmin\tmax\tmean\tmedian\ttotal
    benchmark-fixture measures a sum\tlabel:sum\t3\t1e-09\t1e-09\t1e-09\t1e-09\t3e-09
    EOF

    my %r = run-behave(
      '--parallel', '2', '--order', 'defined',
      '--benchmark',
      '--benchmark-baseline=' ~ $baseline.absolute,
      '--benchmark-threshold=0.01',
      $fix.absolute,
    );
    my $clean = strip-ansi(%r<out>);

    expect($clean).to.include('Benchmark regressions');
    expect($clean).to.include('REGRESSION');
  }
}
