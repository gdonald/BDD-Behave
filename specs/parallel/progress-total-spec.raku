use BDD::Behave;

my $root  = $?FILE.IO.parent.parent.parent;
my $lib   = $root.add('lib');
my $bin   = $root.add('bin/behave');
my $mixed = $root.add('t/fixtures/parallel-mixed-fixture-spec.raku');

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

describe '--progress-total under --parallel', {
  it 'prints a running N/TOTAL after each example event', {
    my %r = run-behave(
      '--parallel', '2', '--order', 'defined', '--progress-total',
      $mixed.absolute,
    );
    my $clean = strip-ansi(%r<out>);

    expect($clean).to.include('(1/9)');
    expect($clean).to.include('(5/9)');
    expect($clean).to.include('(9/9)');
  }

  it 'increments the count for every executed example (pass + fail + pending + skipped)', {
    my %r = run-behave(
      '--parallel', '2', '--order', 'defined', '--progress-total',
      $mixed.absolute,
    );
    my $clean = strip-ansi(%r<out>);

    my @totals;
    for $clean.comb(/ '(' \d+ '/9)' /) -> $match {
      $match ~~ / (\d+) /;
      @totals.push: $/[0].Int;
    }

    expect(@totals).to.contain-exactly(1, 2, 3, 4, 5, 6, 7, 8, 9);
  }

  it 'omits the running total when --progress-total is not set', {
    my %r = run-behave(
      '--parallel', '2', '--order', 'defined',
      $mixed.absolute,
    );
    my $clean = strip-ansi(%r<out>);

    expect($clean).not.to.include('/9)');
  }

  it 'uses the discovered example count as the denominator when filtering examples', {
    my %r = run-behave(
      '--parallel', '2', '--order', 'defined', '--progress-total',
      '--example', 'fail',
      $mixed.absolute,
    );
    my $clean = strip-ansi(%r<out>);

    expect($clean).to.include('(1/2)');
    expect($clean).to.include('(2/2)');
    expect($clean).not.to.include('/9)');
  }
}
