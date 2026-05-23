use BDD::Behave;

my $root    = $?FILE.IO.parent.parent.parent;
my $bin     = $root.add('bin/behave');
my $fixture = $root.add('t/fixtures/dry-run/sample-fixture-spec.raku');

sub run-behave(*@args) {
  my $proc = run('raku', '-Ilib', $bin.absolute, |@args,
                 :out, :err, :env(|%*ENV, BEHAVE_DISABLE_CONFIG => '1'));
  my $out = $proc.out.slurp(:close);
  my $err = $proc.err.slurp(:close);
  %( :exit($proc.exitcode), :$out, :$err );
}

describe 'bin/behave --dry-run', {
  it 'mentions --dry-run in --help', {
    my %r = run-behave('--help');
    expect(%r<exit>).to.be(0);
    expect(%r<out>).to.include('--dry-run');
  }

  it 'lists every example without executing them', {
    my %r = run-behave('--dry-run', $fixture.absolute);
    expect(%r<exit>).to.be(0);
    expect(%r<out>).to.include('Cart');
    expect(%r<out>).to.include('adding items');
    expect(%r<out>).to.include('increments the count');
    expect(%r<out>).to.include('decrements the count');
    expect(%r<out>.contains('passed')).to.be-falsy;
    expect(%r<out>.contains('failed')).to.be-falsy;
  }

  it 'prints an example count summary', {
    my %r = run-behave('--dry-run', $fixture.absolute);
    expect(%r<exit>).to.be(0);
    expect(%r<out>).to.include('5 examples');
  }

  it 'singularizes the count when only one example matches', {
    my %r = run-behave('--dry-run', '--example', 'increments', $fixture.absolute);
    expect(%r<exit>).to.be(0);
    expect(%r<out>).to.include('1 example');
    expect(%r<out>.contains('1 examples')).to.be-falsy;
  }

  it 'marks pending examples with PENDING', {
    my %r = run-behave('--dry-run', $fixture.absolute);
    expect(%r<out>).to.include('persists across reloads (PENDING)');
  }

  it 'marks skipped examples with SKIPPED', {
    my %r = run-behave('--dry-run', $fixture.absolute);
    expect(%r<out>).to.include('is intentionally skipped (SKIPPED)');
  }

  it 'filters by --tag', {
    my %r = run-behave('--dry-run', '--tag', 'fast', $fixture.absolute);
    expect(%r<out>).to.include('increments the count');
    expect(%r<out>.contains('updates the total')).to.be-falsy;
    expect(%r<out>).to.include('1 example');
  }

  it 'filters by --exclude-tag', {
    my %r = run-behave('--dry-run', '--exclude-tag', 'slow', $fixture.absolute);
    expect(%r<out>.contains('decrements the count')).to.be-falsy;
    expect(%r<out>).to.include('increments the count');
  }

  it 'filters by --example substring', {
    my %r = run-behave('--dry-run', '--example', 'decrements', $fixture.absolute);
    expect(%r<out>).to.include('decrements the count');
    expect(%r<out>.contains('increments the count')).to.be-falsy;
    expect(%r<out>).to.include('1 example');
  }

  it 'shows file:line and tag metadata under --verbose', {
    my %r = run-behave('--dry-run', '--verbose', $fixture.absolute);
    expect(%r<out>).to.include('sample-fixture-spec.raku:5');
    expect(%r<out>).to.include('tags: fast');
  }

  it 'exits 1 when a spec fails to load', {
    my $bad = $*TMPDIR.add("behave-dry-run-bad-{$*PID}-{(now * 1e6).Int}-spec.raku");
    $bad.spurt: q:to/END/;
      use BDD::Behave;
      die 'boom';
      END
    my %r = run-behave('--dry-run', $bad.absolute);
    $bad.unlink;
    expect(%r<exit>).to.be(1);
  }
}
