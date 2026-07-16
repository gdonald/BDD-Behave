use BDD::Behave;

my $root           = $?FILE.IO.parent.parent.parent;
my $lib            = $root.add('lib');
my $bin            = $root.add('bin/behave');
my $marker-fixture = $root.add('t/fixtures/parallel/load-marker-fixture-spec.raku');
my $clean-fixture  = $root.add('t/fixtures/parallel-clean-fixture-spec.raku');
my $broken-fixture = $root.add('t/fixtures/broken-fixture-spec.raku');

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

describe '--compile-only', {
  it 'exits 0 and prints nothing when every file loads', {
    my %r = run-behave('--no-config', '--compile-only', $clean-fixture.absolute);

    aggregate-failures {
      expect(%r<exit>).to.be(0);
      expect(%r<out>).to.be('');
    }
  }

  it 'exits 1 on a load error', {
    my %r = run-behave('--no-config', '--compile-only', $broken-fixture.absolute);
    expect(%r<exit>).to.be(1);
  }
}

describe 'the precompile pass of a parallel run', {
  it 'loads each spec file in the pass, discovery, and the worker', {
    my $marker = $*TMPDIR.add("behave-load-marker-spec-{$*PID}-{(now * 1e6).Int}");
    $marker.unlink if $marker.e;
    LEAVE { $marker.unlink if $marker.e }

    my %r = run-behave(
      :env-extra(%(BEHAVE_LOAD_MARKER => $marker.absolute)),
      '--parallel', '1', $marker-fixture.absolute,
    );

    aggregate-failures {
      expect(%r<exit>).to.be(0);
      expect($marker.slurp.lines.elems).to.be(3);
    }
  }

  it 'skips the pass under --no-precompile', {
    my $marker = $*TMPDIR.add("behave-load-marker-spec-np-{$*PID}-{(now * 1e6).Int}");
    $marker.unlink if $marker.e;
    LEAVE { $marker.unlink if $marker.e }

    my %r = run-behave(
      :env-extra(%(BEHAVE_LOAD_MARKER => $marker.absolute)),
      '--parallel', '1', '--no-precompile', $marker-fixture.absolute,
    );

    aggregate-failures {
      expect(%r<exit>).to.be(0);
      expect($marker.slurp.lines.elems).to.be(2);
    }
  }
}
