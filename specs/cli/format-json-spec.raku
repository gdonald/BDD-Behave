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

describe 'bin/behave --format json', {
  it 'is listed in --help output', {
    my %r = run-behave('--help');
    expect(%r<exit>).to.be(0);
    expect(%r<out>).to.include('json');
  }

  it 'emits exactly one JSON document on stdout for a single-file passing run', {
    my %r = run-behave('--format', 'json', '--order', 'defined', $passing.absolute);
    expect(%r<exit>).to.be(0);
    my @lines = %r<out>.lines.grep(*.chars);
    expect(@lines.elems).to.eq(1);
    expect(@lines[0].starts-with('{')).to.be-truthy;
    expect(@lines[0].ends-with('}')).to.be-truthy;
  }

  it 'includes the top-level shape', {
    my %r = run-behave('--format=json', '--order', 'defined', $passing.absolute);
    expect(%r<out>).to.include('"version":1');
    expect(%r<out>).to.include('"examples":');
    expect(%r<out>).to.include('"summary":');
    expect(%r<out>).to.include('"summary_line":');
    expect(%r<out>).to.include('"order":"defined"');
  }

  it 'records statuses for every outcome under a mixed fixture', {
    my %r = run-behave('--format', 'json', '--order', 'defined', $mixed.absolute);
    expect(%r<exit>).to.not.be(0);
    expect(%r<out>).to.include('"status":"passed"');
    expect(%r<out>).to.include('"status":"failed"');
    expect(%r<out>).to.include('"status":"pending"');
    expect(%r<out>).to.include('"status":"skipped"');
  }

  it 'attaches a failure block to failing examples', {
    my %r = run-behave('--format', 'json', '--order', 'defined', $mixed.absolute);
    expect(%r<out>).to.include('"failure":');
  }

  it 'emits matching counts in the summary block', {
    my %r = run-behave('--format', 'json', '--order', 'defined', $mixed.absolute);
    expect(%r<out>).to.include('"total":5');
    expect(%r<out>).to.include('"failed":1');
    expect(%r<out>).to.include('"pending":1');
    expect(%r<out>).to.include('"skipped":1');
    expect(%r<out>).to.include('"passed":2');
  }

  it 'suppresses default per-example output', {
    my %r = run-behave('--format', 'json', '--order', 'defined', $mixed.absolute);
    expect(%r<out>.contains('SUCCESS')).to.be-falsy;
    expect(%r<out>.contains("⮑")).to.be-falsy;
  }
}
