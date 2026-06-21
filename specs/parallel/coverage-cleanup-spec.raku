use BDD::Behave;

my $root = $?FILE.IO.parent.parent.parent;
my $lib  = $root.add('lib');
my $bin  = $root.add('bin/behave');
my $fix  = $root.add('t/fixtures/coverage/slow-fixture-spec.raku');

describe 'an interrupted coverage run', :order<defined>, {
  my $created;
  my $exitcode;
  my $gone;

  before-all {
    # Give the nested run its own TMPDIR so its coverage dir is found without
    # guessing a PID and can't collide with other runs.
    my $sandbox = $*TMPDIR.add("behave-cleanup-{$*PID}-{(now * 1e6).Int}");
    $sandbox.mkdir;

    # Scrub inherited MVM coverage env so this spec running under --coverage
    # can't redirect or filter the nested run's logs.
    my %env = |%*ENV;
    %env<BEHAVE_DISABLE_CONFIG> = '1';
    %env{$_}:delete for %env.keys.grep(*.starts-with('MVM_COVERAGE'));
    %env<BEHAVE_COVERAGE_LOG>:delete;
    %env<TMPDIR> = $sandbox.absolute;

    my $proc = Proc::Async.new(
      'raku', "-I{$lib.absolute}", $bin.absolute,
      '--parallel', '2', '--coverage', '--coverage-format=text',
      '--coverage-include', $fix.absolute, $fix.absolute,
    );
    $proc.stdout.tap(-> $ {});
    $proc.stderr.tap(-> $ {});

    my $promise = $proc.start(:ENV(%env));

    my $covdir;
    my $waited = 0;
    until $covdir.defined {
      $covdir = $sandbox.dir(test => *.starts-with('behave-coverage-parallel-')).first;
      last if $covdir.defined;
      die 'coverage temp dir never appeared' if $waited > 100;
      sleep 0.1;
      $waited++;
    }
    $created = $covdir.defined && $covdir.e;

    $proc.kill(SIGINT);
    $exitcode = (await $promise).exitcode;

    for ^20 {
      unless $covdir.e { $gone = True; last }
      sleep 0.1;
    }

    if $sandbox.e {
      for $sandbox.dir -> $entry {
        if $entry.d {
          for $entry.dir -> $f { $f.unlink if $f.f }
          $entry.rmdir;
        } else {
          $entry.unlink;
        }
      }
      $sandbox.rmdir;
    }
  }

  it 'creates a coverage temp dir during the run', {
    expect($created).to.be-truthy;
  }

  it 'exits through the SIGINT handler rather than completing normally', {
    expect($exitcode).to.be(130);
  }

  it 'removes that temp dir when interrupted instead of stranding it', {
    expect($gone).to.be-truthy;
  }
}
