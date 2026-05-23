use BDD::Behave;

my $root = $?FILE.IO.parent.parent.parent;
my $lib  = $root.add('lib');
my $bin  = $root.add('bin/behave');
my $fix  = $root.add('t/fixtures/profile-fixture-spec.raku');

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

describe '--profile under --parallel', {
  it 'prints a Top N slowest examples section', {
    my %r = run-behave(
      '--parallel', '2', '--order', 'defined', '--profile=2',
      $fix.absolute,
    );
    my $clean = strip-ansi(%r<out>);

    expect($clean).to.include('Top 2 slowest examples');
  }

  it 'lists slow examples sourced from both workers', {
    my %r = run-behave(
      '--parallel', '2', '--order', 'defined', '--profile=3',
      $fix.absolute,
    );
    my $clean = strip-ansi(%r<out>);

    expect($clean).to.include('c slow example');
    expect($clean).to.include('b medium example');
  }

  it 'attaches the example file:line to each row', {
    my %r = run-behave(
      '--parallel', '2', '--order', 'defined', '--profile=2',
      $fix.absolute,
    );
    my $clean = strip-ansi(%r<out>);

    expect($clean).to.include($fix.absolute);
  }

  it 'omits the profile section when --profile is not set', {
    my %r = run-behave(
      '--parallel', '2', '--order', 'defined',
      $fix.absolute,
    );
    my $clean = strip-ansi(%r<out>);

    expect($clean.contains('Top ')).to.be-falsy;
    expect($clean.contains('slowest example')).to.be-falsy;
  }
}
