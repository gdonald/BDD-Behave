use BDD::Behave;
use BDD::Behave::Parallel::Queue;
use BDD::Behave::Parallel::WorkerPool;
use Test::Output;

my $root    = $?FILE.IO.parent.parent.parent;
my $lib     = $root.add('lib');
my $bin     = $root.add('bin/behave');
my $fixture = $root.add('t/fixtures/parallel-clean-fixture-spec.raku');

sub manifest-dir(--> IO::Path) {
  my $dir = $*TMPDIR.add("behave-worker-pool-{$*PID}-{(now * 1e6).Int.base(36)}");
  $dir.mkdir;
  $dir;
}

sub remove-dir(IO::Path $dir --> Nil) {
  return unless $dir.e;
  for $dir.dir -> $entry { $entry.unlink if $entry.f }
  $dir.rmdir;
}

sub pool-for(IO::Path $dir, @events, IO::Path :$coverage-log-dir) {
  BDD::Behave::Parallel::WorkerPool::WorkerPool.new(
    :worker-count(1),
    :worker-argv(('raku', "-I{$lib.absolute}", $bin.absolute)),
    :base-env(%(|%*ENV, BEHAVE_DISABLE_CONFIG => '1')),
    :manifest-dir($dir),
    :$coverage-log-dir,
    :on-event(-> $index, $event { @events.push($event) }),
  );
}

describe 'a pool running one worker', {
  let(:dir, { manifest-dir() });
  let(:events, { [] });
  let(:pool, { pool-for(dir(), events()) });

  before-each {
    pool().launch([[$fixture.absolute ~ ':1']]);
    pool().wait-all;
  }

  after-each {
    pool().cleanup-manifests;
    remove-dir(dir());
  }

  it 'holds one worker', {
    expect(pool().workers.elems).to.be(1);
  }

  it 'reports the worker finished cleanly', {
    expect(pool().any-nonzero-exit).to.be-falsy;
  }

  it 'hands every event the worker sent to the callback', {
    expect(events().grep({ (.<type> // '') eq 'run-summary' }).elems).to.be(1);
  }

  it 'keeps the events on the handle as well', {
    expect(pool().workers[0].events.elems > 0).to.be-truthy;
  }

  it 'takes the manifest away when asked', {
    pool().cleanup-manifests;

    expect(pool().workers[0].manifest-path.e).to.be-falsy;
  }
}

describe 'a pool told to collect coverage', {
  let(:dir, { manifest-dir() });
  let(:log-dir, { manifest-dir() });
  let(:events, { [] });
  let(:pool, { pool-for(dir(), events(), :coverage-log-dir(log-dir())) });

  before-each {
    pool().launch([[$fixture.absolute ~ ':1']]);
    pool().wait-all;
  }

  after-each {
    pool().cleanup-manifests;
    remove-dir(dir());
    remove-dir(log-dir());
  }

  it 'writes a coverage log for the worker', {
    expect(log-dir().dir.grep(*.basename.starts-with('worker-0')).elems).to.be(1);
  }
}

describe 'a pool asked for more manifests than it has workers', {
  let(:dir, { manifest-dir() });

  after-each { remove-dir(dir()) }

  it 'refuses to launch', {
    expect({ pool-for(dir(), []).launch([[], []]) })
      .to.raise-error(/'must equal worker-count'/);
  }
}

describe 'a queue pool told to shut its workers down', {
  let(:dir, { manifest-dir() });

  after-each { remove-dir(dir()) }

  let(:pool, {
    BDD::Behave::Parallel::Queue::QueueWorkerPool.new(
      :worker-count(2),
      :worker-argv(('raku', "-I{$lib.absolute}", $bin.absolute)),
      :spec-files(($fixture.absolute,)),
      :base-env(%(|%*ENV, BEHAVE_DISABLE_CONFIG => '1')),
    );
  });

  it 'asks each worker to stop', {
    pool().launch;
    pool().shutdown-all;
    pool().wait-all;

    expect(pool().workers.grep(*.shutdown-sent).elems).to.be(2);
  }

  it 'leaves every worker finished', {
    pool().launch;
    pool().shutdown-all;
    pool().wait-all;

    expect(pool().workers.grep({ .exit-promise.status ~~ Kept }).elems).to.be(2);
  }
}

describe 'a worker that writes to its error stream', {
  let(:dir, { manifest-dir() });
  let(:events, { [] });
  let(:noisy, {
    my $path = dir().add('noisy-spec.raku');
    $path.spurt(q:to/SPEC/);
    use BDD::Behave;

    note 'a worker complaining';

    describe 'noisy', {
      it 'passes', { expect(1).to.be(1) }
    }
    SPEC
    $path;
  });

  after-each { remove-dir(dir()) }

  it 'passes what the worker wrote through to the parent', {
    my $pool = pool-for(dir(), events());

    my $errors = stderr-from({
      $pool.launch([[noisy().absolute ~ ':6']]);
      $pool.wait-all;
    });

    $pool.cleanup-manifests;

    expect($errors).to.include('a worker complaining');
  }
}
