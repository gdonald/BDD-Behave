use BDD::Behave;

my $root      = $?FILE.IO.parent.parent.parent;
my $bin       = $root.add('bin/behave');
my $fixture-a = $root.add('t/fixtures/cli-file-line-shorthand-spec.raku');
my $fixture-b = $root.add('t/fixtures/cli-line-snap-spec.raku');

sub run-behave(*@args) {
  my $proc = run('raku', '-Ilib', $bin.absolute, |@args,
    :out, :err, :env(|%*ENV, BEHAVE_DISABLE_CONFIG => '1'));
  my $out = $proc.out.slurp(:close);
  my $err = $proc.err.slurp(:close);
  %( :exit($proc.exitcode), :$out, :$err );
}

sub strip-ansi(Str $s) { $s.subst(/ \x1b '[' <[0..9;]>+ 'm' /, '', :g) }

sub make-tree(--> IO::Path) {
  my $dir = $*TMPDIR.add("behave-cli-file-{$*PID}-{(now * 1e6).Int}");
  $dir.mkdir;
  $dir.add('alpha-spec.raku').spurt: q:to/END/;
    use BDD::Behave;
    describe 'tree alpha group', :order<defined>, {
      it 'alpha-tree example', { expect(1).to.eq(1) }
    }
    END
  $dir.add('beta-spec.raku').spurt: q:to/END/;
    use BDD::Behave;
    describe 'tree beta group', :order<defined>, {
      it 'beta-tree example', { expect(2).to.eq(2) }
    }
    END
  $dir;
}

sub rm-tree($p) {
  for $p.dir -> $entry { $entry.d ?? rm-tree($entry) !! $entry.unlink }
  $p.rmdir;
}

describe 'bin/behave positional file arguments', {
  it 'runs every example in a single positional file', {
    my %r = run-behave('--format', 'documentation', $fixture-a.absolute);
    expect(%r<exit>).to.be(0);
    my $clean = strip-ansi(%r<out>);
    expect($clean).to.include('first example');
    expect($clean).to.include('second example');
    expect($clean).to.include('third example');
  }

  it 'runs every example across multiple positional files (union)', {
    my %r = run-behave('--format', 'documentation',
      $fixture-a.absolute, $fixture-b.absolute);
    expect(%r<exit>).to.be(0);
    my $clean = strip-ansi(%r<out>);
    
    # From fixture A
    expect($clean).to.include('first example');
    expect($clean).to.include('second example');
    expect($clean).to.include('third example');
    
    # From fixture B
    expect($clean).to.include('alpha example');
    expect($clean).to.include('beta example');
    expect($clean).to.include('gamma example');
    expect($clean).to.include('delta example');
    expect($clean).to.include('epsilon example');
  }

  it 'expands a positional directory by discovering its *-spec.raku files', {
    my $tree = make-tree;
    my %r = run-behave('--format', 'documentation', $tree.absolute);
    expect(%r<exit>).to.be(0);
    my $clean = strip-ansi(%r<out>);
    expect($clean).to.include('alpha-tree example');
    expect($clean).to.include('beta-tree example');
    rm-tree($tree);
  }

  it 'warns on stderr when a positional arg is neither file nor directory', {
    my %r = run-behave('--format', 'documentation', 'does/not/exist.raku');
    expect(%r<err>).to.include('does/not/exist.raku');
  }
}
