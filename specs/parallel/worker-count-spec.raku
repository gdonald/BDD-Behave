use BDD::Behave;
use BDD::Behave::Parallel;

sub make-fixture-dir(--> IO::Path) {
  my $dir = $*TMPDIR.add("behave-worker-count-{$*PID}-{(now * 1e6).Int}");
  $dir.mkdir;
  $dir;
}

# Each fixture example records whether it ran inside a parallel worker by
# writing BEHAVE_WORKER_INDEX (set only for worker subprocesses) into its own
# probe file.
sub probe-spec(Str $group --> Str) {
  my $template = q:to/END/;
  use BDD::Behave;
  describe 'GROUP', {
    it 'records where it ran', {
      %*ENV<BEHAVE_PROBE_DIR>.IO.add('GROUP')
        .spurt(%*ENV<BEHAVE_WORKER_INDEX> // 'in-process');
      expect(1).to.be(1);
    }
  }
  END
  $template.subst('GROUP', $group, :g);
}

sub run-behave(IO::Path $probe-dir, @argv --> Hash) {
  my %env = |%*ENV;
  %env<BEHAVE_DISABLE_CONFIG> = '1';
  %env<BEHAVE_PROBE_DIR> = $probe-dir.absolute;
  # The suite running this spec may itself be a worker; its index must not
  # leak into the child or every probe reads as a worker.
  %env<BEHAVE_WORKER_INDEX>:delete;
  %env<BEHAVE_WORKER_COUNT>:delete;

  my $proc = run(
    'raku', '-Ilib', 'bin/behave', '--no-config', '--format', 'progress', |@argv,
    :out, :err, :cwd($*CWD), :%env,
  );
  my $stdout = $proc.out.slurp(:close);
  my $stderr = $proc.err.slurp(:close);
  %( :exitcode($proc.exitcode), :$stdout, :$stderr );
}

sub remove-dir(IO::Path $dir --> Nil) {
  return unless $dir.e;
  for $dir.dir -> $entry { $entry.unlink if $entry.f }
  $dir.rmdir;
}

describe 'resolving the worker count', {
  context 'when --parallel was given explicitly', {
    it 'honors the requested count for a single spec file', {
      expect(
        resolve-worker-count(:requested(1), :file-count(1), :cpu-cores(8)),
      ).to.be(1);
    }

    it 'honors the requested count for a whole directory', {
      expect(
        resolve-worker-count(:requested(3), :file-count(20), :cpu-cores(8)),
      ).to.be(3);
    }

    it 'honors a requested count larger than the core count', {
      expect(
        resolve-worker-count(:requested(32), :file-count(20), :cpu-cores(8)),
      ).to.be(32);
    }
  }

  context 'when --parallel was omitted', {
    it 'resolves a single spec file to no workers', {
      expect(
        resolve-worker-count(:file-count(1), :cpu-cores(8)),
      ).to.be(0);
    }

    it 'resolves an empty selection to no workers', {
      expect(
        resolve-worker-count(:file-count(0), :cpu-cores(8)),
      ).to.be(0);
    }

    it 'resolves two spec files to the core count', {
      expect(
        resolve-worker-count(:file-count(2), :cpu-cores(8)),
      ).to.be(8);
    }

    it 'resolves a whole directory to the core count', {
      expect(
        resolve-worker-count(:file-count(159), :cpu-cores(8)),
      ).to.be(8);
    }
  }
}

describe '`behave` deciding where examples run', {
  let(:workspace, {
    my $dir = make-fixture-dir;
    $dir.add('probes').mkdir;
    $dir.add('specs').mkdir;
    $dir;
  });

  let(:probe-dir, { workspace().add('probes') });
  let(:spec-dir,  { workspace().add('specs') });

  after-each {
    my $dir = workspace();
    remove-dir($dir.add('probes'));
    remove-dir($dir.add('specs'));
    remove-dir($dir);
  }

  context 'given a single spec file and no --parallel', {
    let(:probe, {
      spec-dir().add('solo-spec.raku').spurt(probe-spec('solo'));
      run-behave(probe-dir(), [spec-dir().add('solo-spec.raku').absolute]);
      probe-dir().add('solo').slurp;
    });

    it 'runs the example in the behave process itself', {
      expect(probe).to.be('in-process');
    }
  }

  context 'given a single spec file and an explicit --parallel 1', {
    let(:probe, {
      spec-dir().add('solo-spec.raku').spurt(probe-spec('solo'));
      run-behave(
        probe-dir(),
        ['--parallel', '1', spec-dir().add('solo-spec.raku').absolute],
      );
      probe-dir().add('solo').slurp;
    });

    it 'runs the example in a worker subprocess', {
      expect(probe).to.not.be('in-process');
    }
  }

  context 'given a directory of two spec files and no --parallel', {
    let(:probes, {
      spec-dir().add('one-spec.raku').spurt(probe-spec('one'));
      spec-dir().add('two-spec.raku').spurt(probe-spec('two'));
      run-behave(probe-dir(), [spec-dir().absolute]);
      probe-dir().dir.map(*.slurp).List;
    });

    it 'runs both examples in worker subprocesses', {
      expect(probes.grep('in-process').elems).to.be(0);
    }
  }
}
