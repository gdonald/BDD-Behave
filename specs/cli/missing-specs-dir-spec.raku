use BDD::Behave;

my $root = $?FILE.IO.parent.parent.parent;
my $bin  = $root.add('bin/behave');

# The message about a missing specs directory is followed by `exit 1`, so it is
# read back from a run of behave rather than by calling the collector here.
sub remove-tree(IO::Path $node --> Nil) {
  return unless $node.e;

  if $node.d {
    remove-tree($_) for $node.dir;
    $node.rmdir;
  } else {
    $node.unlink;
  }
}

sub run-in(IO::Path $cwd --> Hash) {
  my %env = |%*ENV;
  %env<BEHAVE_DISABLE_CONFIG> = '1';

  my $proc = run(
    'raku', "-I{$root.add('lib').absolute}", $bin.absolute, '--no-config',
    :out, :err, :cwd($cwd.absolute), :%env,
  );

  my $out = $proc.out.slurp(:close);
  my $err = $proc.err.slurp(:close);

  %( :exit($proc.exitcode), :$out, :$err );
}

describe 'running behave where there is no specs directory', {
  let(:empty-dir, {
    my $dir = $*TMPDIR.add("behave-no-specs-{$*PID}-{(now * 1e6).Int.base(36)}");
    $dir.mkdir;
    $dir;
  });

  let(:result, { run-in(empty-dir()) });

  after-each {
    my $dir = empty-dir();
    return unless $dir.e;

    remove-tree($dir);
  }

  it 'exits non-zero', {
    expect(result()<exit>).to.not.be(0);
  }

  it 'says the directory was not found', {
    expect(result()<out> ~ result()<err>).to.include('`specs` directory not found');
  }
}
