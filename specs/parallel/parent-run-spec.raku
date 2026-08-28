use BDD::Behave;
use BDD::Behave::Failures;
use BDD::Behave::Formatter;
use BDD::Behave::Parallel;

# Running the parallel runner from a spec puts the parent side of it in this
# process, so the event handling that turns worker output back into a result is
# exercised here rather than in a subprocess.
my class QuietFormatter does BDD::Behave::Formatter { }

my $root    = $?FILE.IO.parent.parent.parent;
my $lib     = $root.add('lib');
my $bin     = $root.add('bin/behave');
my $manifest-root = $*TMPDIR;

sub run-over(@files, Str :$mode = 'isolated', *%named) {
  my $dir = $manifest-root.add("behave-parent-run-{$*PID}-{(now * 1e6).Int.base(36)}");
  $dir.mkdir;

  LEAVE {
    for $dir.dir -> $entry { $entry.unlink if $entry.f }
    $dir.rmdir if $dir.e;
  }

  # The parent records a worker's failures on the process-wide list, which is
  # the same list this spec file's own examples report through.
  my $watermark = Failures.list.elems;

  LEAVE { Failures.list = Failures.list[^$watermark].list }

  run-parallel(ParallelRunOptions.new(
    :worker-count(1),
    :spec-files(@files.map(*.absolute)),
    :worker-argv(('raku', "-I{$lib.absolute}", $bin.absolute)),
    :discovery-argv(('raku', "-I{$lib.absolute}", $bin.absolute)),
    :base-env(%(|%*ENV, BEHAVE_DISABLE_CONFIG => '1')),
    :formatter(QuietFormatter.new),
    :parallel-mode($mode),
    :order('defined'),
    |%named,
  ));
}

describe 'the parent of a parallel run gathering a passing file', {
  let(:result, { run-over([$root.add('t/fixtures/parallel-clean-fixture-spec.raku')]) });

  it 'counts the examples the worker ran', {
    expect(result().total > 0).to.be-truthy;
  }

  it 'counts them all as passing', {
    expect(result().passed).to.be(result().total);
  }

  it 'records where each one ran', {
    expect(result().executed-locations.elems).to.be(result().total);
  }

  it 'reports a clean exit', {
    expect(result().exit-code).to.be(0);
  }
}

describe 'the parent of a parallel run gathering failures', {
  let(:result, { run-over([$root.add('t/fixtures/failing-fixture-spec.raku')]) });

  it 'counts the failures', {
    expect(result().failed).to.be(3);
  }

  it 'records where each failure was', {
    expect(result().failed-locations.elems).to.be(3);
  }

  it 'keeps the failure details the worker sent', {
    expect(result().failures.elems).to.be(3);
  }

  it 'leaves the exit code alone, since a failed example is not a crash', {
    expect(result().exit-code).to.be(0);
  }
}

describe 'the parent of a parallel run gathering an example that threw', {
  let(:fixture, {
    my $path = $manifest-root.add("behave-parent-throw-{$*PID}-{(now * 1e6).Int.base(36)}-spec.raku");
    $path.spurt(q:to/SPEC/);
    use BDD::Behave;

    describe 'a throwing example', {
      it 'raises rather than failing an expectation', {
        die 'the body gave up';
      }
    }
    SPEC
    $path;
  });

  after-each {
    my $path = fixture();
    $path.unlink if $path.e;
  }

  it 'counts it as a failure', {
    expect(run-over([fixture()]).failed).to.be(1);
  }

  it 'keeps what the exception said', {
    expect(run-over([fixture()]).failures[0]<exception-message>).to.include('the body gave up');
  }
}

describe 'the parent of a parallel run gathering examples that did not run', {
  let(:fixture, {
    my $path = $manifest-root.add("behave-parent-skip-{$*PID}-{(now * 1e6).Int.base(36)}-spec.raku");
    $path.spurt(q:to/SPEC/);
    use BDD::Behave;

    describe 'examples that do not run', {
      xit 'is skipped', { expect(1).to.be(2) }

      pending 'not written yet';
    }
    SPEC
    $path;
  });

  after-each {
    my $path = fixture();
    $path.unlink if $path.e;
  }

  it 'counts the skipped one', {
    expect(run-over([fixture()]).skipped).to.be(1);
  }

  it 'counts the pending one', {
    expect(run-over([fixture()]).pending).to.be(1);
  }
}

describe 'the parent of a parallel run in queue mode', {
  it 'gathers the same passing count', {
    expect(
      run-over([$root.add('t/fixtures/parallel-clean-fixture-spec.raku')], :mode('queue')).passed > 0,
    ).to.be-truthy;
  }
}

describe 'the parent of a parallel run over a file that will not load', {
  let(:broken, {
    my $path = $manifest-root.add("behave-parent-broken-{$*PID}-{(now * 1e6).Int.base(36)}-spec.raku");
    $path.spurt('use BDD::Behave; this is not raku;');
    $path;
  });

  after-each {
    my $path = broken();
    $path.unlink if $path.e;
  }

  it 'reports the load error', {
    expect(run-over([broken()]).load-errors.elems).to.be(1);
  }
}

describe 'the parent of a parallel run gathering an example an around hook never ran', {
  let(:fixture, {
    my $path = $manifest-root.add("behave-parent-around-{$*PID}-{(now * 1e6).Int.base(36)}-spec.raku");
    $path.spurt(q:to/SPEC/);
    use BDD::Behave;

    describe 'an around hook that never continues', {
      around-each -> &continue { Nil }

      it 'never runs its body', { expect(1).to.be(2) }
    }
    SPEC
    $path;
  });

  after-each {
    my $path = fixture();
    $path.unlink if $path.e;
  }

  it 'counts the example as skipped', {
    expect(run-over([fixture()]).skipped).to.be(1);
  }

  it 'counts no failure', {
    expect(run-over([fixture()]).failed).to.be(0);
  }
}

describe 'the parent of a parallel run gathering a retried example', {
  let(:counter, {
    $manifest-root.add("behave-parent-retry-count-{$*PID}-{(now * 1e6).Int.base(36)}.txt");
  });

  let(:fixture, {
    my $path = $manifest-root.add("behave-parent-retry-{$*PID}-{(now * 1e6).Int.base(36)}-spec.raku");
    $path.spurt(qq:to/SPEC/);
    use BDD::Behave;

    my \$counter = '{counter().absolute}'.IO;

    describe 'an example that settles on its second attempt', \{
      it 'passes once it has been tried again', :retry(2), \{
        my \$attempts = \$counter.e ?? \$counter.slurp.Int !! 0;
        \$counter.spurt((\$attempts + 1).Str);
        expect(\$attempts).to.be(1);
      \}
    \}
    SPEC
    $path;
  });

  after-each {
    for fixture(), counter() -> $path {
      $path.unlink if $path.e;
    }
  }

  it 'counts the example as passing', {
    expect(run-over([fixture()]).passed).to.be(1);
  }

  it 'keeps a record of the retry', {
    expect(run-over([fixture()]).retry-records.elems).to.be(1);
  }

  it 'records how many attempts it took', {
    expect(run-over([fixture()]).retry-records[0].attempts).to.be(2);
  }
}
