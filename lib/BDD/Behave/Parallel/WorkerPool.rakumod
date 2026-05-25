unit module BDD::Behave::Parallel::WorkerPool;

use BDD::Behave::Parallel::EventStream;
use BDD::Behave::Parallel::Manifest;

class WorkerHandle is export {
  has Int $.index is required;
  has Proc::Async $.proc is rw;
  has IO::Path $.manifest-path is required;
  has Promise $.exit-promise is required;
  has JsonLineParser $.parser is rw = JsonLineParser.new;
  has @.events is rw;
  has Bool $.finished is rw = False;
  has Int $.exit-code is rw = 0;
  has Str $.stderr-output is rw = '';
  has Int $.attempt is rw = 1;
  has @.crash-codes is rw;
}

class WorkerPool is export {
  has Int $.worker-count is required;
  has @.worker-argv is required;
  has %.base-env;
  has IO::Path $.manifest-dir is required;
  has IO::Path $.coverage-log-dir;
  has Int $.retry-count = 0;
  has &.on-event = sub ($wi, $event) { };
  has &.on-shard-retry = sub ($wi, $attempt, $exit-code) { };

  has WorkerHandle @!workers;
  has @!worker-manifests;

  method launch(@manifests --> Nil) {
    die "manifest count {@manifests.elems} must equal worker-count $!worker-count"
      unless @manifests.elems == $!worker-count;

    @!worker-manifests = @manifests;

    for ^$!worker-count -> $i {
      my @locations = @manifests[$i].List;
      my $manifest-path = $!manifest-dir.add("worker-$i.manifest");
      write-manifest($manifest-path, @locations);

      my $handle = WorkerHandle.new(
        :index($i),
        :proc(Proc::Async),
        :$manifest-path,
        :exit-promise(Promise.new),
      );

      @!workers.push($handle);
      self!spawn-attempt($handle);
    }
  }

  method !spawn-attempt(WorkerHandle $handle --> Nil) {
    my @locations = read-manifest($handle.manifest-path);
    my @files = files-from-manifest(@locations);

    my @argv = @!worker-argv.Slip;
    @argv.push: '--worker-manifest', $handle.manifest-path.absolute;
    @argv.append: @files;

    my %env = |%!base-env;
    %env<BEHAVE_WORKER_INDEX> = $handle.index.Str;
    %env<BEHAVE_WORKER_COUNT> = $!worker-count.Str;

    if $!coverage-log-dir.defined {
      %env<MVM_COVERAGE_LOG>
        = $!coverage-log-dir.add("worker-{$handle.index}.raw").absolute;
      %env<MVM_COVERAGE_CONTROL> = '2';
    }

    my $proc = Proc::Async.new(|@argv);
    $handle.proc = $proc;
    $handle.parser = JsonLineParser.new;
    $handle.events = [];
    $handle.stderr-output = '';

    my $buffering = $!retry-count > 0;

    $proc.stdout.tap(-> $chunk {
      try {
        my @events = $handle.parser.feed($chunk);
        for @events -> $event {
          $handle.events.push($event);
          &!on-event($handle.index, $event) unless $buffering;
        }
        CATCH { default { note "Worker {$handle.index} stdout tap error: {.message}" } }
      }
    });

    $proc.stderr.tap(-> $chunk {
      $handle.stderr-output ~= $chunk;
      $*ERR.print($chunk);
    });

    my $start-promise = $proc.start(:ENV(%env));
    $start-promise.then({
      my $retried = False;
      try {
        my $proc-result = $start-promise.result;
        my $exit-code = $proc-result.exitcode;
        my @tail = $handle.parser.flush;
        for @tail -> $event {
          $handle.events.push($event);
          &!on-event($handle.index, $event) unless $buffering;
        }

        if $exit-code > 1 && $handle.attempt <= $!retry-count {
          $handle.crash-codes.push: $exit-code;
          $handle.attempt++;
          &!on-shard-retry($handle.index, $handle.attempt, $exit-code);
          $retried = True;
          self!spawn-attempt($handle);
        } else {
          $handle.exit-code = $exit-code;
          if $buffering {
            for $handle.events -> $event {
              &!on-event($handle.index, $event);
            }
          }
        }
        CATCH { default { note "Worker {$handle.index} exit handler error: {.message}" } }
      }
      unless $retried {
        $handle.finished = True;
        $handle.exit-promise.keep($handle.exit-code);
      }
    });
  }

  method wait-all(--> Nil) {
    await Promise.allof(@!workers.map(*.exit-promise));
  }

  method workers(--> List) {
    @!workers.List;
  }

  method any-nonzero-exit(--> Bool) {
    @!workers.first({ .exit-code != 0 }).defined;
  }

  method cleanup-manifests {
    for @!workers -> $w {
      $w.manifest-path.unlink if $w.manifest-path.e;
    }
  }
}
