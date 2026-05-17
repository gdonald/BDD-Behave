use BDD::Behave;

my $root    = $?FILE.IO.parent.parent.parent;
my $bin     = $root.add('bin/behave');
my $fixture = $root.add('t/fixtures/benchmark-fixture-spec.raku');

sub run-behave(*@args) {
  my $proc = run('raku', '-Ilib', $bin.absolute, |@args, :out, :err);
  my $out = $proc.out.slurp(:close);
  my $err = $proc.err.slurp(:close);
  %( :exit($proc.exitcode), :$out, :$err );
}

sub strip-ansi(Str $s --> Str) { $s.subst(/\e '[' \d+ 'm'/, '', :g) }

sub tmp-path(Str $ext --> IO::Path) {
  $*TMPDIR.add("behave-fmt-{$*PID}-{(now * 1e6).Int}.$ext");
}

describe 'bin/behave --benchmark text format', {
  it 'renders an aligned table by default under --benchmark', {
    my %r = run-behave('--benchmark', $fixture.absolute);
    expect(%r<exit>).to.be(0);
    my $out = strip-ansi(%r<out>);
    expect($out.contains('DESCRIPTION')).to.be-truthy;
    expect($out.contains('MEDIAN(s)')).to.be-truthy;
    expect($out.contains('─')).to.be-truthy;
  }
}

describe 'bin/behave --benchmark-format', {
  it 'rejects an unknown format', {
    my %r = run-behave('--benchmark-format=yaml', $fixture.absolute);
    expect(%r<exit>).to.not.be(0);
    expect(%r<err>.contains("must be 'text' or 'json'")).to.be-truthy;
  }

  it 'implies --benchmark when set to json', {
    my %r = run-behave('--benchmark-format=json', $fixture.absolute);
    expect(%r<exit>).to.be(0);
    expect(%r<out>.contains('"benchmarks":')).to.be-truthy;
  }

  it 'emits a single JSON object containing version and threshold', {
    my %r = run-behave('--benchmark-format=json', $fixture.absolute);
    my $out = %r<out>;
    expect($out.contains('"version":1')).to.be-truthy;
    expect($out.contains('"threshold":')).to.be-truthy;
  }
}

describe 'bin/behave --benchmark-output', {
  it 'writes the benchmark section to a file and not stdout', {
    my $tmp = tmp-path('json');
    my %r = run-behave('--benchmark-format=json',
                       "--benchmark-output={$tmp.absolute}",
                       $fixture.absolute);
    expect(%r<exit>).to.be(0);
    expect($tmp.e).to.be-truthy;
    my $file = $tmp.slurp;
    expect($file.contains('"benchmarks":')).to.be-truthy;
    expect(%r<out>.contains('"benchmarks":')).to.be-falsy;
    $tmp.unlink;
  }

  it 'works for text format too', {
    my $tmp = tmp-path('txt');
    my %r = run-behave('--benchmark-output=' ~ $tmp.absolute,
                       $fixture.absolute);
    expect(%r<exit>).to.be(0);
    expect($tmp.e).to.be-truthy;
    my $file = strip-ansi($tmp.slurp);
    expect($file.contains('DESCRIPTION')).to.be-truthy;
    $tmp.unlink;
  }
}

describe 'bin/behave comparison arrows', {
  it 'prints an up arrow next to a regressed row and REGRESSION text', {
    my $base = tmp-path('txt');
    run-behave("--benchmark-save={$base.absolute}", $fixture.absolute);
    my %r = run-behave("--benchmark-baseline={$base.absolute}",
                       '--benchmark-threshold=0.0',
                       $fixture.absolute);
    expect(%r<exit>).to.be(0);
    my $out = strip-ansi(%r<out>);
    expect($out.contains('REGRESSION') || $out.contains('↓')).to.be-truthy;
    expect($out.contains('↑') || $out.contains('↓') || $out.contains('→')).to.be-truthy;
    $base.unlink;
  }
}
