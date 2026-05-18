use BDD::Behave;

my $root    = $?FILE.IO.parent.parent.parent;
my $bin     = $root.add('bin/behave');
my $fixture = $root.add('t/fixtures/doc-extraction/sample-fixture-spec.raku');

sub run-behave(*@args) {
  my $proc = run('raku', '-Ilib', $bin.absolute, |@args,
                 :out, :err, :env(|%*ENV, BEHAVE_DISABLE_CONFIG => '1'));
  my $out = $proc.out.slurp(:close);
  my $err = $proc.err.slurp(:close);
  %( :exit($proc.exitcode), :$out, :$err );
}

describe 'bin/behave --doc', {
  it 'lists --doc, --doc-format, and --doc-output in help', {
    my %r = run-behave('--help');
    expect(%r<exit>).to.be(0);
    expect(%r<out>).to.include('--doc');
    expect(%r<out>).to.include('--doc-format');
    expect(%r<out>).to.include('--doc-output');
  }

  it 'emits markdown by default without running examples', {
    my %r = run-behave('--doc', $fixture.absolute);
    expect(%r<exit>).to.be(0);
    expect(%r<out>).to.include('# Calculator');
    expect(%r<out>).to.include('## addition');
    expect(%r<out>).to.include('- adds two positive numbers');
    expect(%r<out>.contains('passed')).to.be-falsy;
    expect(%r<out>.contains('failed')).to.be-falsy;
  }

  it 'honors --doc-format=html', {
    my %r = run-behave('--doc', '--doc-format=html', $fixture.absolute);
    expect(%r<exit>).to.be(0);
    expect(%r<out>).to.include('<!DOCTYPE html>');
    expect(%r<out>).to.include('<h2>Calculator</h2>');
  }

  it 'honors --doc-format=json', {
    my %r = run-behave('--doc', '--doc-format=json', $fixture.absolute);
    expect(%r<exit>).to.be(0);
    expect(%r<out>).to.include('"version":1');
    expect(%r<out>).to.include('"description":"Calculator"');
  }

  it 'rejects unknown --doc-format with exit 2', {
    my %r = run-behave('--doc', '--doc-format=xml', $fixture.absolute);
    expect(%r<exit>).to.be(2);
    expect(%r<err>).to.include("--doc-format must be 'markdown', 'html', or 'json'");
  }

  it 'writes output to --doc-output PATH', {
    my $out-path = $*TMPDIR.add("behave-doc-{$*PID}-{(now * 1e6).Int}.md");
    my %r = run-behave('--doc', "--doc-output={$out-path.absolute}", $fixture.absolute);
    expect(%r<exit>).to.be(0);
    expect(%r<out>.trim).to.eq('');
    expect($out-path.e).to.be-truthy;
    my $contents = $out-path.slurp;
    $out-path.unlink;
    expect($contents).to.include('# Calculator');
  }

  it 'filters by --tag user-facing', {
    my %r = run-behave('--doc', '--tag', 'user-facing', $fixture.absolute);
    expect(%r<exit>).to.be(0);
    expect(%r<out>).to.include('adds two positive numbers');
    expect(%r<out>.contains('subtracts two positive numbers')).to.be-falsy;
  }

  it 'filters by --exclude-tag internal', {
    my %r = run-behave('--doc', '--exclude-tag', 'internal', $fixture.absolute);
    expect(%r<exit>).to.be(0);
    expect(%r<out>).to.include('adds two positive numbers');
    expect(%r<out>.contains('subtracts two positive numbers')).to.be-falsy;
  }

  it 'filters by --example substring', {
    my %r = run-behave('--doc', '--example', 'adds two', $fixture.absolute);
    expect(%r<exit>).to.be(0);
    expect(%r<out>).to.include('adds two positive numbers');
    expect(%r<out>.contains('subtracts two positive numbers')).to.be-falsy;
  }
}
