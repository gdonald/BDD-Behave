use BDD::Behave;

# End-to-end test: spawn a real `behave --parallel N` against a tiny
# spec tree in a temp dir and inspect its stdout/exit code.

sub make-fixture-dir(--> IO::Path) {
  my $dir = $*TMPDIR.add("behave-parallel-fixture-{$*PID}-{(now * 1e6).Int}");
  $dir.mkdir;
  $dir;
}

sub write-spec(IO::Path $dir, Str $name, Str $body) {
  $dir.add($name).spurt($body);
}

sub run-behave(@argv --> Hash) {
  my @cmd = 'raku', '-Ilib', 'bin/behave', |@argv;
  my $proc = run(|@cmd, :out, :err, :cwd($*CWD));
  my $stdout = $proc.out.slurp(:close);
  my $stderr = $proc.err.slurp(:close);
  %( :exitcode($proc.exitcode), :$stdout, :$stderr );
}

describe '`behave --parallel N` end-to-end', {
  let(:fixture, {
    my $dir = make-fixture-dir;

    write-spec($dir, 'a-spec.raku', q:to/END/);
    use BDD::Behave;
    describe 'group A', {
      it 'passes a',  { expect(1).to.be(1); }
      it 'passes a2', { expect(2).to.be(2); }
    }
    END

    write-spec($dir, 'b-spec.raku', q:to/END/);
    use BDD::Behave;
    describe 'group B', {
      it 'passes b',  { expect('hi').to.be('hi'); }
      it 'fails b', { expect(1).to.be(2); }
    }
    END

    write-spec($dir, 'c-spec.raku', q:to/END/);
    use BDD::Behave;
    describe 'group C', {
      it 'passes c', :serial,        { expect(True).to.be-truthy; }
      it 'passes c2',                { expect([1, 2, 3].sum).to.be(6); }
    }
    END

    $dir;
  });

  after-each {
    my $dir = $*LET-RUNTIME.value('fixture');
    if $dir.e {
      for $dir.dir -> $f { $f.unlink if $f.f }
      $dir.rmdir;
    }
  }

  it 'runs all the examples across 2 workers and reports total count', {
    my $dir = $*LET-RUNTIME.value('fixture');
    my %r = run-behave(['--parallel', '2', '--no-config', $dir.absolute]);
    expect(%r<stdout>).to.match(/'Overall: 6 examples'/);
  }

  it 'preserves the failing example in the failure summary', {
    my $dir = $*LET-RUNTIME.value('fixture');
    my %r = run-behave(['--parallel', '2', '--no-config', $dir.absolute]);
    expect(%r<exitcode>).to.be(1);
    expect(%r<stdout>).to.match(/'1 failed'/);
  }

  it 'rejects --parallel combined with --bisect', {
    my $dir = $*LET-RUNTIME.value('fixture');
    my %r = run-behave(['--parallel', '2', '--bisect', '--no-config', $dir.absolute]);
    expect(%r<exitcode>).to.be(2);
    expect(%r<stderr>).to.match(/'mutually exclusive'/);
  }

  it 'rejects --parallel=0', {
    my $dir = $*LET-RUNTIME.value('fixture');
    my %r = run-behave(['--parallel=0', '--no-config', $dir.absolute]);
    expect(%r<exitcode>).to.be(2);
  }
}

describe 'BEHAVE_WORKER_INDEX / BEHAVE_WORKER_COUNT inside specs', {
  let(:fixture, {
    my $dir = make-fixture-dir;
    write-spec($dir, 'worker-id-spec.raku', q:to/END/);
    use BDD::Behave;
    use BDD::Behave::Worker;
    describe 'worker identity', {
      it 'has BEHAVE_WORKER_COUNT matching --parallel value', {
        expect(BDD::Behave::Worker.count).to.be(2);
      }
      it 'has BEHAVE_WORKER_INDEX in [0, count)', {
        my $idx = BDD::Behave::Worker.id;
        expect($idx >= 0 && $idx < BDD::Behave::Worker.count).to.be-truthy;
      }
    }
    END
    $dir;
  });

  after-each {
    my $dir = $*LET-RUNTIME.value('fixture');
    if $dir.e {
      for $dir.dir -> $f { $f.unlink if $f.f }
      $dir.rmdir;
    }
  }

  it 'sets the env vars so worker code can read them', {
    my $dir = $*LET-RUNTIME.value('fixture');
    my %r = run-behave(['--parallel', '2', '--no-config', $dir.absolute]);
    expect(%r<exitcode>).to.be(0);
    expect(%r<stdout>).to.match(/'2 passed'/);
  }
}
