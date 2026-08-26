use BDD::Behave;
use BDD::Behave::Configuration;

sub make-fixture-dir(--> IO::Path) {
  my $dir = $*TMPDIR.add("behave-parallel-mode-{$*PID}-{(now * 1e6).Int}");
  $dir.mkdir;
  $dir;
}

# A spec file that records the process it ran in.
sub pid-spec(Str $group --> Str) {
  my $template = q:to/END/;
  use BDD::Behave;

  describe 'GROUP', {
    it 'records the process it ran in', {
      %*ENV<BEHAVE_PROBE_DIR>.IO.add('GROUP').spurt($*PID.Str);
      expect(1).to.be(1);
    }
  }
  END
  $template.subst('GROUP', $group, :g);
}

# A spec file that records the worker slot it ran in.
sub slot-spec(Str $group --> Str) {
  my $template = q:to/END/;
  use BDD::Behave;

  describe 'GROUP', {
    it 'records the worker slot it ran in', {
      %*ENV<BEHAVE_PROBE_DIR>.IO.add('GROUP')
        .spurt(%*ENV<BEHAVE_WORKER_INDEX> // 'none');
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

describe 'resolving the parallel mode', {
  it 'resolves an unset mode to isolated', {
    expect(BDD::Behave::Configuration::resolve-parallel-mode(Str)).to.eq('isolated');
  }

  it 'keeps an explicitly requested mode', {
    expect(BDD::Behave::Configuration::resolve-parallel-mode('queue')).to.eq('queue');
  }

  it 'lower-cases a requested mode', {
    expect(BDD::Behave::Configuration::resolve-parallel-mode('LPT')).to.eq('lpt');
  }

  it 'names isolated as the default mode', {
    expect(BDD::Behave::Configuration::DEFAULT-PARALLEL-MODE).to.eq('isolated');
  }

  it 'carries the default into a fresh configuration', {
    expect(BDD::Behave::Configuration::defaults().parallel-mode).to.eq('isolated');
  }

  it 'accepts every documented mode', {
    expect(
      BDD::Behave::Configuration::PARALLEL-MODES.grep({
        BDD::Behave::Configuration::is-parallel-mode($_)
      }).elems,
    ).to.eq(3);
  }

  it 'rejects a mode it does not know', {
    expect(BDD::Behave::Configuration::is-parallel-mode('threads')).to.be-falsy;
  }
}

describe 'the default mode running spec files', {
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

  context 'given two spec files', {
    let(:pids, {
      spec-dir().add('first-spec.raku').spurt(pid-spec('first'));
      spec-dir().add('second-spec.raku').spurt(pid-spec('second'));

      run-behave(probe-dir(), [spec-dir().absolute]);

      probe-dir().dir.grep(*.f).map(*.slurp).unique.list;
    });

    it 'runs each file in its own process', {
      expect(pids().elems).to.eq(2);
    }
  }

  context 'given more spec files than workers', {
    let(:slots, {
      for <alpha beta gamma delta> -> $name {
        spec-dir().add($name ~ '-spec.raku').spurt(slot-spec($name));
      }

      run-behave(probe-dir(), ['--parallel', '2', spec-dir().absolute]);

      probe-dir().dir.grep(*.f).map(*.slurp).sort.list;
    });

    it 'keeps every worker slot inside the requested worker count', {
      expect(slots().grep({ $_ eq '0' | '1' }).elems).to.eq(4);
    }
  }
}
