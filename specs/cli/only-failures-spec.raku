use BDD::Behave;

my $root    = $?FILE.IO.parent.parent.parent;
my $lib     = $root.add('lib');
my $bin     = $root.add('bin/behave');
my $failing = $root.add('t/fixtures/failing-fixture-spec.raku');
my $passing = $root.add('specs/expectations/be-between-spec.raku');

sub fresh-workdir(--> IO::Path) {
  my $dir = $*TMPDIR.add("behave-only-failures-{$*PID}-{(now * 1e6).Int.base(36)}");
  $dir.mkdir;
  $dir;
}

sub rm-rf($node) {
  if $node.d {
    rm-rf($_) for $node.dir;
    $node.rmdir if $node.e;
  } else {
    $node.unlink if $node.e;
  }
}

sub run-behave-in(IO::Path $dir, *@args) {
  my %env = |%*ENV;
  my $proc = run(
    'raku', "-I{$lib.absolute}", $bin.absolute, |@args,
    :cwd($dir.absolute),
    :out, :err,
    :env(%env),
  );
  my $out = $proc.out.slurp(:close);
  my $err = $proc.err.slurp(:close);
  %( :exit($proc.exitcode), :$out, :$err );
}

describe 'bin/behave --only-failures', {
  it 'writes .behave-failures after a failing run', {
    my $dir = fresh-workdir();
    LEAVE { rm-rf($dir) }
    my %r = run-behave-in($dir, '--order', 'defined', $failing.absolute);
    expect(%r<exit>).to.not.be(0);
    my $path = $dir.add('.behave-failures');
    expect($path.e).to.be-truthy;
    my @lines = $path.slurp.lines.grep(*.chars);
    expect(@lines.elems).to.be(3);
    for @lines -> $line {
      expect($line.contains($failing.basename)).to.be-truthy;
    }
  }

  it 'leaves .behave-failures empty (but present) after a fully passing run', {
    my $dir = fresh-workdir();
    LEAVE { rm-rf($dir) }
    my %r = run-behave-in($dir, '--order', 'defined', $passing.absolute);
    expect(%r<exit>).to.be(0);
    my $path = $dir.add('.behave-failures');
    expect($path.e).to.be-truthy;
    expect($path.slurp).to.be('');
  }

  it 'runs only previously-failing examples when --only-failures is set', {
    my $dir = fresh-workdir();
    LEAVE { rm-rf($dir) }
    run-behave-in($dir, '--order', 'defined', $failing.absolute);
    my %second = run-behave-in($dir, '--only-failures', '--order', 'defined', $failing.absolute);
    expect(%second<exit>).to.not.be(0);
    expect(%second<out>.contains('3 examples,')).to.be-truthy;
    expect(%second<out>.contains('1 passed')).to.be-falsy;
  }

  it 'warns and runs all examples when --only-failures has no file to read', {
    my $dir = fresh-workdir();
    LEAVE { rm-rf($dir) }
    my %r = run-behave-in($dir, '--only-failures', '--order', 'defined', $passing.absolute);
    expect(%r<exit>).to.be(0);
    expect(%r<err>.contains('not found')).to.be-truthy;
  }

  it 'updates .behave-failures to remove entries whose examples now pass', {
    my $dir = fresh-workdir();
    LEAVE { rm-rf($dir) }
    my $path = $dir.add('.behave-failures');
    $path.spurt: "{$passing.absolute}:5\n";

    run-behave-in($dir, '--order', 'defined', $passing.absolute);
    expect($path.slurp).to.be('');
  }

  it 'preserves entries whose examples did not run this time', {
    my $dir = fresh-workdir();
    LEAVE { rm-rf($dir) }
    my $path = $dir.add('.behave-failures');
    $path.spurt: "specs/other-suite-spec.raku:42\n";

    run-behave-in($dir, '--order', 'defined', $passing.absolute);

    my @after = $path.slurp.lines.grep(*.chars);
    expect(@after.elems).to.be(1);
    expect(@after[0]).to.be('specs/other-suite-spec.raku:42');
  }

  it 'accepts --failures-path=PATH for a custom location', {
    my $dir = fresh-workdir();
    LEAVE { rm-rf($dir) }
    my $custom = $dir.add('my-failures.txt');
    my %r = run-behave-in($dir, '--failures-path', $custom.absolute, '--order', 'defined', $failing.absolute);
    expect(%r<exit>).to.not.be(0);
    expect($custom.e).to.be-truthy;
    expect($dir.add('.behave-failures').e).to.be-falsy;
  }
}
