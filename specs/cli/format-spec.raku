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

describe 'bin/behave --format', {
  it 'defaults to the default formatter (no flag)', {
    my %r = run-behave('--order', 'defined', $fixture.absolute);
    expect(%r<exit>).to.be(0);
    expect(%r<out>).to.include('SUCCESS');
  }

  it 'accepts --format default as an explicit selection', {
    my %r = run-behave('--format', 'default', '--order', 'defined', $fixture.absolute);
    expect(%r<exit>).to.be(0);
    expect(%r<out>).to.include('SUCCESS');
  }

  it 'accepts --format=default as the joined form', {
    my %r = run-behave('--format=default', '--order', 'defined', $fixture.absolute);
    expect(%r<exit>).to.be(0);
    expect(%r<out>).to.include('SUCCESS');
  }

  it 'rejects an unknown formatter with a non-zero exit and stderr message', {
    my %r = run-behave('--format', 'doesnotexist', $fixture.absolute);
    expect(%r<exit>).to.not.be(0);
    expect(%r<err>).to.include("unknown --format 'doesnotexist'");
    expect(%r<err>).to.include('available:');
  }

  it 'lists "default" in the --help output', {
    my %r = run-behave('--help');
    expect(%r<exit>).to.be(0);
    expect(%r<out>).to.include('--format');
    expect(%r<out>).to.include('default');
  }
}
