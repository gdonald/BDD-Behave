use BDD::Behave;

my $root = $?FILE.IO.parent.parent.parent;
my $lib  = $root.add('lib');
my $bin  = $root.add('bin/behave');

sub run-behave(*@args, :$in-data = '', :$cwd) {
  my %env = |%*ENV;
  %env<BEHAVE_DISABLE_CONFIG> = '1';
  my $proc = Proc::Async.new(
    'raku', "-I{$lib.absolute}", $bin.absolute, |@args, :w,
  );
  my $out = '';
  my $err = '';
  $proc.stdout.tap(-> $c { $out ~= $c });
  $proc.stderr.tap(-> $c { $err ~= $c });
  my $done = $cwd.defined ?? $proc.start(:cwd($cwd.absolute), :%env)
                          !! $proc.start(:%env);
  $proc.print($in-data) if $in-data.chars;
  $proc.close-stdin;
  my $result = await $done;
  %( :exit($result.exitcode), :$out, :$err );
}

sub fresh-dir(--> IO::Path) {
  my $d = $*TMPDIR.add("behave-watch-cli-spec-{$*PID}-{(now * 1e6).Int.base(36)}");
  $d.mkdir;
  $d;
}

sub rm-rf($n) {
  if $n.d {
    rm-rf($_) for $n.dir;
    $n.rmdir if $n.e;
  } else {
    $n.unlink if $n.e;
  }
}

describe 'bin/behave --watch', {
  it 'documents --watch in --help', {
    my %r = run-behave('--help');
    expect(%r<out>).to.include('--watch');
    expect(%r<out>).to.include('--watch-path');
  }

  it 'rejects --watch combined with --bisect', {
    my %r = run-behave('--watch', '--bisect');
    expect(%r<exit>).to.be(2);
    expect(%r<err>).to.include('mutually exclusive');
  }

  it 'rejects --watch combined with --parallel', {
    my %r = run-behave('--watch', '--parallel', '2');
    expect(%r<exit>).to.be(2);
    expect(%r<err>).to.include('mutually exclusive');
  }

  it 'enters the watch loop, runs the initial run, then exits on q', {
    my $dir = fresh-dir();
    LEAVE { rm-rf($dir) }
    my $sp = $dir.add('specs'); $sp.mkdir;
    my $spec = $sp.add('passing-spec.raku');
    $spec.spurt: q:to/END/;
      use BDD::Behave;
      describe 'watch passing', {
        it 'passes', { expect(1).to.be(1) }
      }
      END
    my %r = run-behave(
      '--watch', '--watch-path', $sp.absolute,
      $spec.absolute,
      :in-data("q\n"),
      :cwd($dir),
    );
    expect(%r<exit>).to.be(0);
    expect(%r<out>).to.include('behave watch');
  }
}
