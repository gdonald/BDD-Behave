use BDD::Behave;

my $root    = $?FILE.IO.parent.parent.parent;
my $bin     = $root.add('bin/behave');
my $fixture = $root.add('specs/expectations/be-between-spec.raku');

sub run-behave(*@args) {
  my $proc = run('raku', '-Ilib', $bin.absolute, |@args, :out, :err);
  my $out = $proc.out.slurp(:close);
  my $err = $proc.err.slurp(:close);
  %( :exit($proc.exitcode), :$out, :$err );
}

sub strip-ansi(Str $s) { $s.subst(/ \x1b '[' <[0..9;]>+ 'm' /, '', :g) }

describe 'bin/behave --format', {
  it 'defaults to the progress formatter when no --format is given', {
    my %r = run-behave('--order', 'defined', $fixture.absolute);
    expect(%r<exit>).to.be(0);
    my @lines = strip-ansi(%r<out>).lines.grep(*.chars);
    expect(@lines[0].comb.unique.sort.join).to.eq('.');
  }

  it 'accepts --format tree as the indented-tree formatter', {
    my %r = run-behave('--format', 'tree', '--order', 'defined', $fixture.absolute);
    expect(%r<exit>).to.be(0);
    expect(%r<out>).to.include('SUCCESS');
  }

  it 'accepts --format=tree as the joined form', {
    my %r = run-behave('--format=tree', '--order', 'defined', $fixture.absolute);
    expect(%r<exit>).to.be(0);
    expect(%r<out>).to.include('SUCCESS');
  }

  it 'rejects an unknown formatter with a non-zero exit and stderr message', {
    my %r = run-behave('--format', 'doesnotexist', $fixture.absolute);
    expect(%r<exit>).to.not.be(0);
    expect(%r<err>).to.include("unknown --format 'doesnotexist'");
    expect(%r<err>).to.include('available:');
  }

  it 'rejects the old --format default name (it has been renamed to tree)', {
    my %r = run-behave('--format', 'default', $fixture.absolute);
    expect(%r<exit>).to.not.be(0);
    expect(%r<err>).to.include("unknown --format 'default'");
  }

  it 'lists every built-in formatter in the --help output', {
    my %r = run-behave('--help');
    expect(%r<exit>).to.be(0);
    expect(%r<out>).to.include('--format');
    expect(%r<out>).to.include('progress');
    expect(%r<out>).to.include('tree');
  }
}
