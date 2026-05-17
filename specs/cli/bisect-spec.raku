use BDD::Behave;

my $root    = $?FILE.IO.parent.parent.parent;
my $bin     = $root.add('bin/behave');
my $bisect  = $root.add('t/fixtures/bisect-fixture-spec.raku');
my $failing = $root.add('t/fixtures/failing-fixture-spec.raku');
my $passing = $root.add('specs/expectations/be-between-spec.raku');

sub run-behave(*@args) {
  my $proc = run('raku', '-Ilib', $bin.absolute, |@args, :out, :err);
  my $out = $proc.out.slurp(:close);
  my $err = $proc.err.slurp(:close);
  %( :exit($proc.exitcode), :$out, :$err );
}

describe 'bin/behave --only-example', {
  it 'restricts execution to a single example by file:line', {
    my %r = run-behave('--format=tree', '--order', 'defined',
                       '--only-example', "{$bisect.absolute}:29",
                       $bisect.absolute);
    expect(%r<exit>).to.be(0);
    expect(%r<out>.contains('1 example,')).to.be-truthy;
    expect(%r<out>.contains('1 passed')).to.be-truthy;
    expect(%r<out>.contains('expects counter to be zero')).to.be-truthy;
    expect(%r<out>.contains('pollutes counter')).to.be-falsy;
  }

  it 'accepts repeated --only-example with OR semantics', {
    my %r = run-behave('--order', 'defined',
                       '--only-example', "{$bisect.absolute}:20",
                       '--only-example', "{$bisect.absolute}:29",
                       $bisect.absolute);
    expect(%r<exit>).to.not.be(0);
    expect(%r<out>.contains('2 examples,')).to.be-truthy;
    expect(%r<out>.contains('1 failed')).to.be-truthy;
  }

  it 'accepts --only-example=LOC form', {
    my %r = run-behave('--order', 'defined',
                       "--only-example={$bisect.absolute}:29",
                       $bisect.absolute);
    expect(%r<exit>).to.be(0);
    expect(%r<out>.contains('1 passed')).to.be-truthy;
  }

  it 'matches by basename + line', {
    my %r = run-behave('--order', 'defined',
                       '--only-example', 'bisect-fixture-spec.raku:29',
                       $bisect.absolute);
    expect(%r<exit>).to.be(0);
    expect(%r<out>.contains('1 passed')).to.be-truthy;
  }
}

describe 'bin/behave --bisect-data', {
  it 'emits behave-executed: and behave-failed: lines', {
    my %r = run-behave('--bisect-data', '--order', 'defined', $bisect.absolute);
    expect(%r<exit>).to.not.be(0);
    my @lines = %r<out>.lines;
    my @executed = @lines.grep(*.starts-with('behave-executed: '));
    my @failed   = @lines.grep(*.starts-with('behave-failed: '));
    expect(@executed.elems).to.be(5);
    expect(@failed.elems).to.be(1);
    expect(@failed[0].ends-with(':29')).to.be-truthy;
  }

  it 'suppresses the normal example output', {
    my %r = run-behave('--bisect-data', '--order', 'defined', $bisect.absolute);
    expect(%r<out>.contains('SUCCESS')).to.be-falsy;
    expect(%r<out>.contains('FAILURE')).to.be-falsy;
    expect(%r<out>.contains('Failures:')).to.be-falsy;
  }

  it 'is rejected when combined with --bisect', {
    my %r = run-behave('--bisect', '--bisect-data', $bisect.absolute);
    expect(%r<exit>).to.not.be(0);
    expect(%r<err>.contains('mutually exclusive')).to.be-truthy;
  }
}

describe 'bin/behave --bisect', {
  it 'finds the minimal prior set for an order-dependent failure', {
    my %r = run-behave('--bisect', $bisect.absolute);
    expect(%r<exit>).to.not.be(0);
    expect(%r<out>.contains('Bisect: 1 failing example')).to.be-truthy;
    expect(%r<out>.contains('Minimal reproduction')).to.be-truthy;
    expect(%r<out>.contains(':20')).to.be-truthy;
    expect(%r<out>.contains(':29')).to.be-truthy;
    expect(%r<out>.contains(':12')).to.be-falsy;
    expect(%r<out>.contains(':16')).to.be-falsy;
    expect(%r<out>.contains(':25')).to.be-falsy;
  }

  it 'reports failures that reproduce in isolation as not order-dependent', {
    my %r = run-behave('--bisect', $failing.absolute);
    expect(%r<exit>).to.not.be(0);
    expect(%r<out>.contains('not order-dependent')).to.be-truthy;
  }

  it 'reports no work when the initial run has no failures', {
    my %r = run-behave('--bisect', $passing.absolute);
    expect(%r<exit>).to.be(0);
    expect(%r<out>.contains('no failing examples')).to.be-truthy;
  }

  it 'emits a runnable reproduction command for the minimal set', {
    my %r = run-behave('--bisect', $bisect.absolute);
    expect(%r<out>.contains('Reproduce with:')).to.be-truthy;
    expect(%r<out>.contains('bin/behave')).to.be-truthy;
    expect(%r<out>.contains('--only-example')).to.be-truthy;
    expect(%r<out>.contains('--order defined')).to.be-truthy;
  }
}
