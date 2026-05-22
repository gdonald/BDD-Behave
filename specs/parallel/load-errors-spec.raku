use BDD::Behave;

my $root  = $?FILE.IO.parent.parent.parent;
my $lib   = $root.add('lib');
my $bin   = $root.add('bin/behave');
my $clean = $root.add('t/fixtures/parallel-clean-fixture-spec.raku');
my $bad   = $root.add('t/fixtures/parallel-bad-spec.raku');

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

describe 'bin/behave --parallel load errors', {
  it 'surfaces load errors in the summary and exits non-zero', {
    my %r = run-behave(
      '--parallel', '2', '--order', 'defined',
      $clean.absolute, $bad.absolute,
    );

    expect(%r<exit>).to.be(1);
    expect(%r<out>).to.include('1 spec file failed to load');
    expect(%r<out>).to.include('Load errors (1)');
    expect(%r<out>).to.include($bad.basename);
  }

  it 'still runs examples in spec files that did load', {
    my %r = run-behave(
      '--parallel', '2', '--order', 'defined',
      $clean.absolute, $bad.absolute,
    );

    expect(%r<out>).to.include('Overall: 2 examples');
    expect(%r<out>).to.include('2 passed');
  }
}
