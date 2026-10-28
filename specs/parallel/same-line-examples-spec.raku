use BDD::Behave;

my constant GROUPED-SPEC = q:to/END/;
  use BDD::Behave;

  describe 'routes', {
    for <signup login status> -> $name {
      it "routes $name", { expect($name).not.to.eq('status') }
    }
  }
  END

my constant TOP-LEVEL-SPEC = q:to/END/;
  use BDD::Behave;

  for <alpha beta gamma> -> $name {
    it "checks $name", { expect($name.chars).to.be(5) }
  }
  END

sub run-parallel(Str $mode, Str $source --> Str) {
  my $dir = $*TMPDIR.add("behave-same-line-{$mode}-{$*PID}-{(now * 1e6).Int}");
  $dir.mkdir;

  my $spec = $dir.add('same-line-spec.raku');
  $spec.spurt($source);

  my %env = |%*ENV;
  %env<BEHAVE_DISABLE_CONFIG> = '1';
  %env<BEHAVE_WORKER_INDEX>:delete;
  %env<BEHAVE_WORKER_COUNT>:delete;

  my $proc = run(
    'raku', '-Ilib', 'bin/behave', '--no-config', '--format', 'tap',
    '--order', 'defined', '--parallel', '2', '--parallel-mode', $mode,
    $spec.absolute,
    :out, :err, :cwd($*CWD), :%env,
  );
  my $stdout = $proc.out.slurp(:close);
  $proc.err.slurp(:close);

  for $dir.dir -> $entry { $entry.unlink if $entry.f }
  $dir.rmdir;

  $stdout;
}

sub reported-names(Str $tap-output --> List) {
  $tap-output.lines.grep(/^ 'not '? 'ok ' \d+ ' - '/).map(*.subst(/^ 'not '? 'ok ' \d+ ' - '/, '')).sort.List;
}

for <isolated lpt queue> -> $mode {
  describe "running examples registered in a loop in $mode mode", {
    context 'when the examples share a group', {
      let(:tap-output, { run-parallel($mode, GROUPED-SPEC) });

      it 'reports each example under its own description', {
        expect(reported-names(tap-output)).to.eq(('routes routes login', 'routes routes signup', 'routes routes status'));
      }

      it 'reports the failure under the example that failed', {
        expect(tap-output).to.match(/^^ 'not ok ' \d+ ' - routes routes status' $$/);
      }
    }

    context 'when the examples sit at the top of the file', {
      let(:tap-output, { run-parallel($mode, TOP-LEVEL-SPEC) });

      it 'runs and reports each example once', {
        expect(reported-names(tap-output)).to.eq(('checks alpha', 'checks beta', 'checks gamma'));
      }
    }
  }
}

my constant LATER-FAILURE-SPEC = q:to/END/;
  use BDD::Behave;

  describe 'routes', {
    for <signup login status> -> $name {
      it "routes $name", { expect($name).to.eq('status') }
    }
  }
  END

sub rerun-failures(@first-run-options --> Str) {
  my $dir = $*TMPDIR.add("behave-same-line-rerun-{$*PID}-{(now * 1e6).Int}");
  $dir.mkdir;

  my $spec = $dir.add('same-line-spec.raku');
  my $failures = $dir.add('failures.txt');
  $spec.spurt(LATER-FAILURE-SPEC);

  my %env = |%*ENV;
  %env<BEHAVE_DISABLE_CONFIG> = '1';
  %env<BEHAVE_WORKER_INDEX>:delete;
  %env<BEHAVE_WORKER_COUNT>:delete;

  my @common = 'raku', '-Ilib', 'bin/behave', '--no-config', '--format', 'tap',
    '--order', 'defined', '--failures-path', $failures.absolute;

  my $first = run(|@common, |@first-run-options, $spec.absolute, :out, :err, :cwd($*CWD), :%env);
  $first.out.slurp(:close);
  $first.err.slurp(:close);

  my $rerun = run(|@common, '--only-failures', $spec.absolute, :out, :err, :cwd($*CWD), :%env);
  my $stdout = $rerun.out.slurp(:close);
  $rerun.err.slurp(:close);

  for $dir.dir -> $entry { $entry.unlink if $entry.f }
  $dir.rmdir;

  $stdout;
}

describe 'rerunning the failures of examples registered in a loop', {
  context 'after a serial run', {
    it 'runs the failed examples after the first on the line by their own occurrence', {
      expect(reported-names(rerun-failures(()))).to.eq(('routes routes login', 'routes routes signup'));
    }
  }

  context 'after a parallel run', {
    it 'runs the failed examples after the first on the line by their own occurrence', {
      expect(reported-names(rerun-failures(('--parallel', '2', '--parallel-mode', 'queue'))))
        .to.eq(('routes routes login', 'routes routes signup'));
    }
  }
}

my constant SHARED-ONE-LINE-SPEC = q:to/END/;
  use BDD::Behave;

  shared-examples 'a pair', { it 'checks the first', { expect(1).to.be(1) }; it 'checks the second', { expect(2).to.be(2) } };

  describe 'one group', { it-behaves-like 'a pair' }

  describe 'another group', { it-behaves-like 'a pair' }
  END

describe 'running shared examples declared on one line with their group', {
  for <lpt queue> -> $mode {
    it "runs each example once in $mode mode", {
      expect(reported-names(run-parallel($mode, SHARED-ONE-LINE-SPEC))).to.eq((
        "another group behaves like 'a pair' checks the first",
        "another group behaves like 'a pair' checks the second",
        "one group behaves like 'a pair' checks the first",
        "one group behaves like 'a pair' checks the second",
      ));
    }
  }
}
