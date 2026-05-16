use BDD::Behave;

my $root    = $?FILE.IO.parent.parent.parent;
my $bin     = $root.add('bin/behave');
my $failing = $root.add('t/fixtures/failing-fixture-spec.raku');
my $passing = $root.add('specs/expectations/be-between-spec.raku');

sub run-behave(*@args) {
  my $proc = run('raku', '-Ilib', $bin.absolute, |@args, :out, :err);
  my $out = $proc.out.slurp(:close);
  my $err = $proc.err.slurp(:close);
  %( :exit($proc.exitcode), :$out, :$err );
}

sub fail-count(Str $out --> Int) {
  ($out ~~ / (\d+) \s+ 'failed' /) ?? +$0 !! 0;
}

describe 'bin/behave --fail-fast', {
  it 'without --fail-fast reports every failure in the fixture', {
    my %r = run-behave($failing.absolute);
    expect(%r<exit>).to.not.be(0);
    expect(fail-count(%r<out>)).to.be(3);
  }

  it 'with --fail-fast stops after the first failure', {
    my %r = run-behave('--fail-fast', $failing.absolute);
    expect(%r<exit>).to.not.be(0);
    expect(fail-count(%r<out>)).to.be(1);
    expect(%r<out>.contains('Aborted after 1 failure (--fail-fast)')).to.be-truthy;
  }

  it 'with --fail-fast=2 stops after the second failure', {
    my %r = run-behave('--fail-fast=2', $failing.absolute);
    expect(%r<exit>).to.not.be(0);
    expect(fail-count(%r<out>)).to.be(2);
    expect(%r<out>.contains('Aborted after 2 failures (--fail-fast)')).to.be-truthy;
  }

  it 'with --fail-fast on a passing run does not abort or print the banner', {
    my %r = run-behave('--fail-fast', $passing.absolute);
    expect(%r<exit>).to.be(0);
    expect(%r<out>.contains('Aborted after')).to.be-falsy;
  }

  it 'rejects --fail-fast=0 with a non-zero exit code', {
    my %r = run-behave('--fail-fast=0', $passing.absolute);
    expect(%r<exit>).to.not.be(0);
    expect(%r<err>.contains('--fail-fast=N requires a positive integer')).to.be-truthy;
  }

  it 'rejects --fail-fast=abc with a non-zero exit code', {
    my %r = run-behave('--fail-fast=abc', $passing.absolute);
    expect(%r<exit>).to.not.be(0);
    expect(%r<err>.contains('--fail-fast=N requires a positive integer')).to.be-truthy;
  }

  it 'stops loading additional suites after the threshold is met', {
    my %r = run-behave('--fail-fast', $failing.absolute, $passing.absolute);
    expect(%r<exit>).to.not.be(0);
    expect(fail-count(%r<out>)).to.be(1);
    # The passing fixture's describe header should never have been printed
    # because we aborted after the failing fixture.
    expect(%r<out>.contains('be-between')).to.be-falsy;
  }
}
