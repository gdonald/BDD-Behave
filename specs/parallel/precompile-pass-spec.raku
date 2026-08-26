use BDD::Behave;
use BDD::Behave::Parallel;

my $root           = $?FILE.IO.parent.parent.parent;
my $lib            = $root.add('lib');
my $bin            = $root.add('bin/behave');
my $marker-fixture = $root.add('t/fixtures/parallel/load-marker-fixture-spec.raku');
my $second-fixture = $root.add('t/fixtures/parallel/load-marker-second-fixture-spec.raku');
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

describe 'deciding whether to run the precompile pass', {
  it 'skips the pass for a single spec file', {
    expect(should-precompile(:file-count(1))).to.be-falsy;
  }

  it 'skips the pass for an empty selection', {
    expect(should-precompile(:file-count(0))).to.be-falsy;
  }

  it 'runs the pass for more than one spec file', {
    expect(should-precompile(:file-count(2))).to.be-truthy;
  }

  it 'skips the pass when it was not requested', {
    expect(should-precompile(:file-count(20), :!requested)).to.be-falsy;
  }

  it 'skips the pass when discovery runs in this process', {
    expect(should-precompile(:file-count(20), :discovery-in-process)).to.be-falsy;
  }
}

describe 'the precompile pass of a parallel run', {
  let(:marker, {
    my $path = $*TMPDIR.add("behave-load-marker-spec-{$*PID}-{(now * 1e6).Int}");
    $path.unlink if $path.e;
    $path;
  });

  after-each {
    my $path = marker();
    $path.unlink if $path.e;
  }

  context 'given a single spec file', {
    let(:run, {
      run-behave(
        :env-extra(%(BEHAVE_LOAD_MARKER => marker().absolute)),
        '--parallel', '1', $marker-fixture.absolute,
      );
    });

    it 'runs the file without a precompile subprocess', {
      aggregate-failures {
        expect(run()<exit>).to.be(0);
        expect(marker().slurp.lines.elems).to.be(2);
      }
    }
  }

  context 'given more than one spec file', {
    let(:run, {
      run-behave(
        :env-extra(%(BEHAVE_LOAD_MARKER => marker().absolute)),
        '--parallel', '2', $marker-fixture.absolute, $second-fixture.absolute,
      );
    });

    it 'loads each file in the pass, discovery, and its worker', {
      aggregate-failures {
        expect(run()<exit>).to.be(0);
        expect(marker().slurp.lines.elems).to.be(6);
      }
    }
  }

  context 'given more than one spec file under --no-precompile', {
    let(:run, {
      run-behave(
        :env-extra(%(BEHAVE_LOAD_MARKER => marker().absolute)),
        '--parallel', '2', '--no-precompile',
        $marker-fixture.absolute, $second-fixture.absolute,
      );
    });

    it 'loads each file in discovery and its worker only', {
      aggregate-failures {
        expect(run()<exit>).to.be(0);
        expect(marker().slurp.lines.elems).to.be(4);
      }
    }
  }
}
