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

describe 'bin/behave --format junit', {
  it 'is listed in --help output', {
    my %r = run-behave('--help');
    expect(%r<exit>).to.be(0);
    expect(%r<out>).to.include('junit');
  }

  it 'emits an XML prolog and testsuites root for a passing run', {
    my %r = run-behave('--format', 'junit', '--order', 'defined', $passing.absolute);
    expect(%r<exit>).to.be(0);
    expect(%r<out>).to.match(/^^ '<?xml version="1.0" encoding="UTF-8"?>'/);
    expect(%r<out>).to.include('<testsuites');
    expect(%r<out>).to.include('</testsuites>');
  }

  it 'opens one testsuite for a single-file run', {
    my %r = run-behave('--format=junit', '--order', 'defined', $passing.absolute);
    expect(%r<out>.comb(/'<testsuite '/).elems).to.eq(1);
  }

  it 'renders <failure>, <skipped> children for the mixed fixture', {
    my %r = run-behave('--format', 'junit', '--order', 'defined', $mixed.absolute);
    expect(%r<exit>).to.not.be(0);
    expect(%r<out>).to.include('<failure');
    expect(%r<out>).to.include('<skipped');
    expect(%r<out>).to.include('<![CDATA[');
  }

  it 'records aggregate counts on the testsuites root', {
    my %r = run-behave('--format', 'junit', '--order', 'defined', $mixed.absolute);
    expect(%r<out>).to.include('tests="5"');
    expect(%r<out>).to.include('failures="1"');
    expect(%r<out>).to.include('skipped="2"');
  }

  it 'suppresses default per-example output', {
    my %r = run-behave('--format', 'junit', '--order', 'defined', $mixed.absolute);
    expect(%r<out>.contains('SUCCESS')).to.be-falsy;
    expect(%r<out>.contains("⮑")).to.be-falsy;
  }
}
