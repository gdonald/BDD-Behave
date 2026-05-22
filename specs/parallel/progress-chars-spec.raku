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

describe '--parallel progress chars', {
  it 'emits one progress char per executed example regardless of parent lookup', {
    my %r = run-behave('--parallel', '2', '--order', 'defined', $mixed.absolute);
    my $clean = strip-ansi(%r<out>);
    my $line  = $clean.lines.first // '';

    expect($line.comb(/'.'/).elems).to.be(5);
    expect($line.comb(/'F'/).elems).to.be(2);
    expect($line.comb(/'*'/).elems).to.be(1);
    expect($line.comb(/'S'/).elems).to.be(1);
  }

  it 'reports the full count in the summary even under --parallel', {
    my %r = run-behave('--parallel', '2', '--order', 'defined', $mixed.absolute);
    expect(%r<out>).to.include('9 examples');
    expect(%r<out>).to.include('2 failed');
    expect(%r<out>).to.include('5 passed');
  }
}
