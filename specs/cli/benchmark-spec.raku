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

sub strip-ansi(Str $s --> Str) {
  $s.subst(/\e '[' \d+ 'm'/, '', :g);
}

sub tmp-baseline(--> IO::Path) {
  $*TMPDIR.add("behave-baseline-cli-{$*PID}-{(now * 1e6).Int}.txt");
}

describe 'bin/behave --benchmark', {
  it 'is absent by default', {
    my %r = run-behave($fixture.absolute);
    expect(%r<exit>).to.be(0);
    expect(strip-ansi(%r<out>).contains('Benchmarks (')).to.be-falsy;
  }

  it 'prints a Benchmarks section with --benchmark', {
    my %r = run-behave('--benchmark', $fixture.absolute);
    expect(%r<exit>).to.be(0);
    my $out = strip-ansi(%r<out>);
    expect($out.contains('Benchmarks (')).to.be-truthy;
    expect($out.contains('label:sum')).to.be-truthy;
  }

  it 'lists labeled benchmarks under separate keys', {
    my %r = run-behave('--benchmark', $fixture.absolute);
    my $out = strip-ansi(%r<out>);
    expect($out.contains('label:a')).to.be-truthy;
    expect($out.contains('label:b')).to.be-truthy;
  }

  it 'is implied by --benchmark-iterations greater than 1', {
    my %r = run-behave('--benchmark-iterations=2', $fixture.absolute);
    expect(%r<exit>).to.be(0);
    expect(strip-ansi(%r<out>).contains('Benchmarks (')).to.be-truthy;
  }

  it 'rejects --benchmark-iterations=0', {
    my %r = run-behave('--benchmark-iterations=0', $fixture.absolute);
    expect(%r<exit>).to.not.be(0);
    expect(%r<err>.contains('positive integer')).to.be-truthy;
  }

  it 'rejects --benchmark-iterations=abc', {
    my %r = run-behave('--benchmark-iterations=abc', $fixture.absolute);
    expect(%r<exit>).to.not.be(0);
    expect(%r<err>.contains('positive integer')).to.be-truthy;
  }

  it 'rejects --benchmark-threshold=abc', {
    my %r = run-behave('--benchmark-threshold=abc', $fixture.absolute);
    expect(%r<exit>).to.not.be(0);
    expect(%r<err>.contains('non-negative number')).to.be-truthy;
  }
}

describe 'bin/behave --benchmark-save', {
  it 'writes a baseline file containing the current summaries', {
    my $tmp = tmp-baseline();
    my %r = run-behave("--benchmark-save={$tmp.absolute}", $fixture.absolute);
    expect(%r<exit>).to.be(0);
    expect($tmp.e).to.be-truthy;
    my $content = $tmp.slurp;
    expect($content.starts-with('# behave-benchmark-baseline')).to.be-truthy;
    expect($content.contains('label:sum')).to.be-truthy;
    $tmp.unlink;
  }

  it 'implies --benchmark and prints the Benchmarks section', {
    my $tmp = tmp-baseline();
    my %r = run-behave("--benchmark-save={$tmp.absolute}", $fixture.absolute);
    expect(strip-ansi(%r<out>).contains('Benchmarks (')).to.be-truthy;
    $tmp.unlink;
  }
}

describe 'bin/behave --benchmark-baseline', {
  it 'prints a comparison block when given a matching baseline', {
    my $tmp = tmp-baseline();
    run-behave("--benchmark-save={$tmp.absolute}", $fixture.absolute);
    my %r = run-behave("--benchmark-baseline={$tmp.absolute}", $fixture.absolute);
    expect(%r<exit>).to.be(0);
    my $out = strip-ansi(%r<out>);
    expect($out.contains('BASELINE')
           || $out.contains('Benchmark regressions')
           || $out.contains('Benchmark comparison')).to.be-truthy;
    $tmp.unlink;
  }

  it 'dies with a clear error when the baseline file does not exist', {
    my %r = run-behave('--benchmark-baseline=/tmp/no-such-baseline-file.txt',
                       $fixture.absolute);
    expect(%r<exit>).to.not.be(0);
  }
}
