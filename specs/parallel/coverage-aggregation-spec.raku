use BDD::Behave;
use BDD::Behave::Coverage;

my $root = $?FILE.IO.parent.parent.parent;
my $lib  = $root.add('lib');
my $bin  = $root.add('bin/behave');
my $fix  = $root.add('t/fixtures/coverage/parallel-fixture-spec.raku');

sub strip-ansi(Str $s --> Str) {
  $s.subst(/ \e '[' <[0..9;]>* 'm' /, '', :g);
}

sub run-behave(*@args) {
  my %env = |%*ENV;
  %env<BEHAVE_DISABLE_CONFIG> = '1';

  # When this spec itself runs under --coverage, the outer worker exports
  # MVM coverage env (MVM_COVERAGE_LOG, MVM_COVERAGE_CONTROL, and a
  # user-supplied MVM_COVERAGE_FILES path filter) that would otherwise
  # instrument the nested behave's parent process, redirect its hits at the
  # outer log, and filter out the fixture (which lives under t/, not lib/).
  # Scrub it so the nested run measures coverage exactly as it would
  # standalone.
  %env{$_}:delete for %env.keys.grep(*.starts-with('MVM_COVERAGE'));
  %env<BEHAVE_COVERAGE_LOG>:delete;

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

describe '--coverage under --parallel', {
  it 'merges per-worker hits into a single 100% report', {
    my %r = run-behave(
      '--parallel', '2', '--order', 'defined',
      '--coverage', '--coverage-format=text',
      '--coverage-include', $fix.absolute,
      $fix.absolute,
    );

    expect(%r<exit>).to.be(0);

    my $clean = strip-ansi(%r<out>);

    expect($clean).to.include('Coverage report');
    expect($clean).to.include('16/16 lines (100.0%)');
  }

  it 'emits coverage from any worker (lines from both buckets)', {
    my %r = run-behave(
      '--parallel', '2', '--order', 'defined',
      '--coverage', '--coverage-format=json',
      '--coverage-include', $fix.absolute,
      $fix.absolute,
    );

    expect(%r<exit>).to.be(0);

    my $brace = %r<out>.index('{');
    my $json  = %r<out>.substr($brace);
    my %report = BDD::Behave::Coverage::minimal-json-parse($json);

    expect(%report<summary><lines><covered>).to.be(16);
    expect(%report<summary><lines><total>).to.be(16);

    my @covered = %report<files>[0]<covered-line-numbers>.list;
    # Body lines from bucket A (15, 19) and bucket B (25, 29) both appear.
    expect(@covered.first(15).defined).to.be-truthy;
    expect(@covered.first(19).defined).to.be-truthy;
    expect(@covered.first(25).defined).to.be-truthy;
    expect(@covered.first(29).defined).to.be-truthy;
  }

  it 'falls below --coverage-minimum when only one bucket runs', {
    my %r = run-behave(
      '--parallel', '2', '--order', 'defined',
      '--coverage', '--coverage-format=text',
      '--coverage-include', $fix.absolute,
      '--coverage-minimum', '90',
      '--example', 'bucket A',
      $fix.absolute,
    );

    expect(%r<exit>).to.be(1);

    my $clean = strip-ansi(%r<out>);

    expect($clean).to.include('11/16 lines (68.8%)');

    my $stderr = strip-ansi(%r<err>);
    expect($stderr).to.include('coverage 68.75% is below the required minimum 90.00%');
  }

  it 'passes --coverage-minimum when merged percentage meets the bar', {
    my %r = run-behave(
      '--parallel', '2', '--order', 'defined',
      '--coverage', '--coverage-format=text',
      '--coverage-include', $fix.absolute,
      '--coverage-minimum', '100',
      $fix.absolute,
    );

    expect(%r<exit>).to.be(0);
  }
}
