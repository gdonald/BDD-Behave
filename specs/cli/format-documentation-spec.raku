use BDD::Behave;

my $root    = $?FILE.IO.parent.parent.parent;
my $bin     = $root.add('bin/behave');
my $passing = $root.add('specs/expectations/be-between-spec.raku');
my $mixed   = $root.add('t/fixtures/progress-fixture-spec.raku');

sub run-behave(*@args) {
  my $proc = run('raku', '-Ilib', $bin.absolute, |@args, :out, :err);
  my $out = $proc.out.slurp(:close);
  my $err = $proc.err.slurp(:close);
  %( :exit($proc.exitcode), :$out, :$err );
}

sub strip-ansi(Str $s) { $s.subst(/ \x1b '[' <[0..9;]>+ 'm' /, '', :g) }

describe 'bin/behave --format documentation', {
  it 'is listed in --help output', {
    my %r = run-behave('--help');
    expect(%r<exit>).to.be(0);
    expect(%r<out>).to.include('documentation');
  }

  it 'runs an all-passing suite without SUCCESS/arrow noise', {
    my %r = run-behave('--format', 'documentation', '--order', 'defined', $passing.absolute);
    expect(%r<exit>).to.be(0);
    my $clean = strip-ansi(%r<out>);
    expect($clean.contains('SUCCESS')).to.be-falsy;
    expect($clean.contains("⮑")).to.be-falsy;
  }

  it 'prints group descriptions without quotes or arrows', {
    my %r = run-behave('--format=documentation', '--order', 'defined', $passing.absolute);
    my $clean = strip-ansi(%r<out>);
    expect($clean).to.match(/^^ \w/);
  }

  it 'annotates failing/pending/skipped examples with suffix labels', {
    my %r = run-behave('--format', 'documentation', '--order', 'defined', $mixed.absolute);
    expect(%r<exit>).to.not.be(0);
    my $clean = strip-ansi(%r<out>);
    expect($clean).to.include('(FAILED)');
    expect($clean).to.include('(PENDING)');
    expect($clean).to.include('(SKIPPED)');
  }

  it 'still prints failure details and the counts line', {
    my %r = run-behave('--format', 'documentation', '--order', 'defined', $mixed.absolute);
    my $clean = strip-ansi(%r<out>);
    expect($clean).to.include('Failures:');
    expect($clean).to.include('5 examples');
    expect($clean).to.include('1 failed');
    expect($clean).to.include('1 pending');
    expect($clean).to.include('1 skipped');
  }

  it 'matches the run counts under --format tree', {
    my %r-tree = run-behave('--format', 'tree',          '--order', 'defined', $mixed.absolute);
    my %r-doc  = run-behave('--format', 'documentation', '--order', 'defined', $mixed.absolute);
    expect(%r-tree<exit>).to.eq(%r-doc<exit>);
    for <5 examples|1 failed|1 pending|1 skipped|2 passed>.split('|') -> $needle {
      expect(strip-ansi(%r-tree<out>).contains($needle)).to.be-truthy;
      expect(strip-ansi(%r-doc<out>).contains($needle)).to.be-truthy;
    }
  }
}
