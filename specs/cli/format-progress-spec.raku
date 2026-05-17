use BDD::Behave;

my $root         = $?FILE.IO.parent.parent.parent;
my $bin          = $root.add('bin/behave');
my $passing      = $root.add('specs/expectations/be-between-spec.raku');
my $mixed        = $root.add('t/fixtures/progress-fixture-spec.raku');

sub run-behave(*@args) {
  my $proc = run('raku', '-Ilib', $bin.absolute, |@args, :out, :err);
  my $out = $proc.out.slurp(:close);
  my $err = $proc.err.slurp(:close);
  %( :exit($proc.exitcode), :$out, :$err );
}

sub strip-ansi(Str $s) { $s.subst(/ \x1b '[' <[0..9;]>+ 'm' /, '', :g) }

describe 'bin/behave --format progress', {
  it 'is listed in --help alongside the default formatter', {
    my %r = run-behave('--help');
    expect(%r<exit>).to.be(0);
    expect(%r<out>).to.include('progress');
  }

  it 'runs an all-passing suite and emits one dot per example', {
    my %r = run-behave('--format', 'progress', '--order', 'defined', $passing.absolute);
    expect(%r<exit>).to.be(0);
    my $clean = strip-ansi(%r<out>);
    expect($clean.contains('.')).to.be-truthy;
    expect($clean.contains('SUCCESS')).to.be-falsy;
    expect($clean.contains("⮑")).to.be-falsy;
  }

  it 'emits a single dots line followed by the summary', {
    my %r = run-behave('--format', 'progress', '--order', 'defined', $passing.absolute);
    my @lines = strip-ansi(%r<out>).lines.grep(*.chars);
    expect(@lines[0].comb.unique.sort.join).to.eq('.');
    expect(@lines.grep(*.contains('passed')).elems).to.eq(1);
  }

  it 'prints F for failures, * for pending, S for skipped in the mixed fixture', {
    my %r = run-behave('--format=progress', '--order', 'defined', $mixed.absolute);
    expect(%r<exit>).to.not.be(0);
    my $clean = strip-ansi(%r<out>);
    my @lines = $clean.lines;
    my $stream = @lines[0];
    expect($stream).to.include('.');
    expect($stream).to.include('F');
    expect($stream).to.include('*');
    expect($stream).to.include('S');
  }

  it 'still prints failure details and the counts line', {
    my %r = run-behave('--format', 'progress', '--order', 'defined', $mixed.absolute);
    my $clean = strip-ansi(%r<out>);
    expect($clean).to.include('Failures:');
    expect($clean).to.include('5 examples');
    expect($clean).to.include('1 failed');
    expect($clean).to.include('1 pending');
    expect($clean).to.include('1 skipped');
    expect($clean).to.include('2 passed');
  }

  it 'returns the same counts as the tree formatter for a mixed run', {
    my %r-tree     = run-behave('--format', 'tree',     '--order', 'defined', $mixed.absolute);
    my %r-progress = run-behave('--format', 'progress', '--order', 'defined', $mixed.absolute);
    expect(%r-tree<exit>).to.eq(%r-progress<exit>);
    for <5 examples|1 failed|1 pending|1 skipped|2 passed>.split('|') -> $needle {
      expect(strip-ansi(%r-tree<out>).contains($needle)).to.be-truthy;
      expect(strip-ansi(%r-progress<out>).contains($needle)).to.be-truthy;
    }
  }
}
