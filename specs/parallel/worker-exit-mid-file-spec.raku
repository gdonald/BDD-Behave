use BDD::Behave;

my constant EXITING-SPEC = q:to/END/;
  use BDD::Behave;

  describe 'a file whose worker exits', {
    it 'passes before the worker exits', {
      expect(1).to.be(1);
    }

    it 'ends the worker process', {
      exit 3;
    }
  }
  END

sub run-exiting-file(Str $mode --> Str) {
  my $dir = $*TMPDIR.add("behave-exit-mid-file-{$mode}-{$*PID}-{(now * 1e6).Int}");
  $dir.mkdir;

  my $spec-file = $dir.add('exiting-spec.raku');
  $spec-file.spurt(EXITING-SPEC);

  my %env = |%*ENV;
  %env<BEHAVE_DISABLE_CONFIG> = '1';
  %env<BEHAVE_WORKER_INDEX>:delete;
  %env<BEHAVE_WORKER_COUNT>:delete;

  my $proc = run(
    'raku', '-Ilib', 'bin/behave', '--no-config', '--format', 'tap',
    '--order', 'defined', '--parallel', '1', '--parallel-mode', $mode,
    $spec-file.absolute,
    :out, :err, :cwd($*CWD), :%env,
  );
  my $stdout = $proc.out.slurp(:close);
  $proc.err.slurp(:close);

  $spec-file.unlink;
  $dir.rmdir;

  $stdout;
}

for <isolated lpt queue> -> $mode {
  describe "a worker that exits partway through a file in $mode mode", {
    it 'still reports the example that passed before it exited', {
      expect(run-exiting-file($mode)).to.match(/^^ 'ok ' \d+ ' - a file whose worker exits passes before the worker exits' $$/);
    }
  }
}
