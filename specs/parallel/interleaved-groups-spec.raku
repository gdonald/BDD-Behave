use BDD::Behave;

# The first file keeps its group open until the second file has reported an
# example, so the parent receives the second file's events while the first
# file's group-start is still unmatched.
my constant FIRST-SPEC = q:to/END/;
  use BDD::Behave;

  describe 'the first file', {
    it 'stays open until the second file has reported an example', {
      my $probe-dir = %*ENV<BEHAVE_PROBE_DIR>.IO;
      $probe-dir.add('first-started').spurt('');

      for ^400 {
        last if $probe-dir.add('second-reported').e;
        sleep 0.05;
      }

      expect(1).to.be(1);
    }
  }
  END

my constant SECOND-SPEC = q:to/END/;
  use BDD::Behave;

  describe 'the second file', {
    it 'runs while the first file is open', {
      my $probe-dir = %*ENV<BEHAVE_PROBE_DIR>.IO;

      for ^400 {
        last if $probe-dir.add('first-started').e;
        sleep 0.05;
      }

      expect(1).to.be(1);
    }

    it 'tells the first file it has reported an example', {
      %*ENV<BEHAVE_PROBE_DIR>.IO.add('second-reported').spurt('');

      expect(1).to.be(1);
    }
  }
  END

sub run-interleaved(Str $mode --> Str) {
  my $dir = $*TMPDIR.add("behave-interleaved-{$mode}-{$*PID}-{(now * 1e6).Int}");
  $dir.mkdir;

  my $first  = $dir.add('first-spec.raku');
  my $second = $dir.add('second-spec.raku');
  $first.spurt(FIRST-SPEC);
  $second.spurt(SECOND-SPEC);

  my %env = |%*ENV;
  %env<BEHAVE_DISABLE_CONFIG> = '1';
  %env<BEHAVE_PROBE_DIR> = $dir.absolute;
  %env<BEHAVE_WORKER_INDEX>:delete;
  %env<BEHAVE_WORKER_COUNT>:delete;

  my $proc = run(
    'raku', '-Ilib', 'bin/behave', '--no-config', '--format', 'tap',
    '--order', 'defined', '--parallel', '2', '--parallel-mode', $mode,
    $first.absolute, $second.absolute,
    :out, :err, :cwd($*CWD), :%env,
  );
  my $stdout = $proc.out.slurp(:close);
  $proc.err.slurp(:close);

  for $dir.dir -> $entry { $entry.unlink if $entry.f }
  $dir.rmdir;

  $stdout;
}

for <isolated lpt queue> -> $mode {
  describe "running two files at once in $mode mode", {
    it 'names each example under the groups of its own file', {
      my $tap-output = run-interleaved($mode);

      aggregate-failures {
        expect($tap-output).to.match(/^^ 'ok ' \d+ ' - the second file runs while the first file is open' $$/);
        expect($tap-output).to.match(/^^ 'ok ' \d+ ' - the first file stays open until the second file has reported an example' $$/);
      }
    }
  }
}
