use BDD::Behave;

my $root    = $?FILE.IO.parent.parent.parent;
my $bin     = $root.add('bin/behave');
my $fixture = $root.add('t/fixtures/cli-file-line-shorthand-spec.raku');

sub run-behave(*@args) {
  my $proc = run('raku', '-Ilib', $bin.absolute, |@args,
                 :out, :err, :env(|%*ENV, BEHAVE_DISABLE_CONFIG => '1'));
  my $out = $proc.out.slurp(:close);
  my $err = $proc.err.slurp(:close);
  %( :exit($proc.exitcode), :$out, :$err );
}

sub strip-ansi(Str $s) { $s.subst(/ \x1b '[' <[0..9;]>+ 'm' /, '', :g) }

describe 'bin/behave FILE:LINE positional shorthand', {
  it 'runs only the example at the specified line', {
    my %r = run-behave('--format', 'documentation', "{$fixture.absolute}:4");
    expect(%r<exit>).to.be(0);
    my $clean = strip-ansi(%r<out>);
    expect($clean).to.include('first example');
    expect($clean.contains('second example')).to.be-falsy;
    expect($clean.contains('third example')).to.be-falsy;
  }

  it 'composes multiple FILE:LINE args with OR (union) semantics', {
    my %r = run-behave('--format', 'documentation',
                      "{$fixture.absolute}:4", "{$fixture.absolute}:6");
    expect(%r<exit>).to.be(0);
    my $clean = strip-ansi(%r<out>);
    expect($clean).to.include('first example');
    expect($clean).to.include('third example');
    expect($clean.contains('second example')).to.be-falsy;
  }

  it 'composes with explicit --only-example (same OR list)', {
    my %r = run-behave('--format', 'documentation',
                      "{$fixture.absolute}:4",
                      '--only-example', "{$fixture.absolute}:5");
    expect(%r<exit>).to.be(0);
    my $clean = strip-ansi(%r<out>);
    expect($clean).to.include('first example');
    expect($clean).to.include('second example');
    expect($clean.contains('third example')).to.be-falsy;
  }

  it 'is left untouched when the FILE part does not exist on disk', {
    my %r = run-behave('does/not/exist-spec.raku:42');
    # The arg passes through as a normal spec path, which then fails to load.
    expect(%r<exit>).to.not.be(0);
    expect(%r<err>).to.include('does/not/exist-spec.raku');
  }

  it 'still runs the bare FILE without :LINE as a normal spec', {
    my %r = run-behave('--format', 'documentation', $fixture.absolute);
    expect(%r<exit>).to.be(0);
    my $clean = strip-ansi(%r<out>);
    expect($clean).to.include('first example');
    expect($clean).to.include('second example');
    expect($clean).to.include('third example');
  }
}
