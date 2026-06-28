use BDD::Behave;

my $root    = $?FILE.IO.parent.parent.parent;
my $lib     = $root.add('lib');
my $bin     = $root.add('bin/behave');
my $failing = $root.add('t/fixtures/failing-fixture-spec.raku');

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

describe 'bin/behave --parallel failure reporting', {
  it 'prints the Failures: section under --parallel', {
    my %r = run-behave('--parallel', '2', '--order', 'defined', $failing.absolute);
    expect(%r<exit>).to.not.be(0);
    expect(%r<out>).to.include('Failures:');
    expect(%r<out>).to.include($failing.basename);
  }

  it 'renders Expected: / to be: lines for each parallel failure', {
    my %r = run-behave('--parallel', '2', '--order', 'defined', $failing.absolute);
    expect(%r<out>).to.include('Expected:');
    expect(%r<out>).to.include('to be:');
  }

  it 'lists exactly one row per failure (no duplicate cross-worker bleed)', {
    my %r = run-behave('--parallel', '2', '--order', 'defined', $failing.absolute);
    my $count = +%r<out>.match(/'✗'/, :g).elems;
    expect($count).to.be(3);
  }

  context 'under --format json', {
    let(:json-out, {
      run-behave('--parallel', '2', '--format', 'json', '--order', 'defined', $failing.absolute)<out>;
    });

    it 'carries the expectations array through the parallel JSON output', {
      expect(json-out).to.include('"expectations":');
    }

    it 'carries the given value through the parallel JSON output', {
      expect(json-out).to.include('"given":"a"');
    }

    it 'carries the expected value through the parallel JSON output', {
      expect(json-out).to.include('"expected":"b"');
    }
  }
}
