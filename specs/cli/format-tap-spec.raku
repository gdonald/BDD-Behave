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

describe 'bin/behave --format tap', {
  it 'is listed in --help output', {
    my %r = run-behave('--help');
    expect(%r<exit>).to.be(0);
    expect(%r<out>).to.include('tap');
  }

  it 'emits TAP version 13 header and 1..N plan first', {
    my %r = run-behave('--format', 'tap', '--order', 'defined', $passing.absolute);
    expect(%r<exit>).to.be(0);
    my @lines = %r<out>.lines.grep(*.chars);
    expect(@lines[0]).to.eq('TAP version 13');
    expect(@lines[1]).to.match(/^^ '1..' \d+ $$/);
  }

  it 'renders ok / not ok / TODO / SKIP directives in a mixed run', {
    my %r = run-behave('--format=tap', '--order', 'defined', $mixed.absolute);
    expect(%r<exit>).to.not.be(0);
    expect(%r<out>).to.include('ok 1 -');
    expect(%r<out>).to.include('not ok 2 -');
    expect(%r<out>).to.include('# TODO');
    expect(%r<out>).to.include('# SKIP');
  }

  it 'includes a YAML diagnostic block for failures', {
    my %r = run-behave('--format', 'tap', '--order', 'defined', $mixed.absolute);
    expect(%r<out>).to.include('  ---');
    expect(%r<out>).to.include('  ...');
    expect(%r<out>).to.include('severity:');
  }

  it 'suppresses default per-example output', {
    my %r = run-behave('--format', 'tap', '--order', 'defined', $mixed.absolute);
    expect(%r<out>.contains('SUCCESS')).to.be-falsy;
    expect(%r<out>.contains("⮑")).to.be-falsy;
  }
}
