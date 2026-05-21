unit module BDD::Behave::Parallel::WorkerPool;

use BDD::Behave::Parallel::EventStream;
use BDD::Behave::Parallel::Manifest;

class WorkerHandle is export {
  has Int $.index is required;
  has Proc::Async $.proc is required;
  has IO::Path $.manifest-path is required;
  has Promise $.exit-promise is required;
  has JsonLineParser $.parser = JsonLineParser.new;
  has @.events;
  has Bool $.finished is rw = False;
  has Int $.exit-code is rw = 0;
  has Str $.stderr-output is rw = '';
}

class WorkerPool is export {
  has Int $.worker-count is required;
  has @.worker-argv is required;
  has %.base-env;
  has IO::Path $.manifest-dir is required;
  has &.on-event = sub ($wi, $event) { };

  has WorkerHandle @!workers;

  method launch(@manifests --> Nil) {
    die "manifest count {@manifests.elems} must equal worker-count $!worker-count"
      unless @manifests.elems == $!worker-count;

    for ^$!worker-count -> $i {
      my @locations = @manifests[$i].List;
      my $manifest-path = $!manifest-dir.add("worker-$i.manifest");
      write-manifest($manifest-path, @locations);

      my @files = files-from-manifest(@locations);

      my @argv = @!worker-argv.Slip;
      @argv.push: '--worker-manifest', $manifest-path.absolute;
      @argv.append: @files;

      my %env = |%!base-env;
      %env<BEHAVE_WORKER_INDEX> = $i.Str;
      %env<BEHAVE_WORKER_COUNT> = $!worker-count.Str;

      my $proc = Proc::Async.new(|@argv);

      my $handle = WorkerHandle.new(
        :index($i),
        :$proc,
        :$manifest-path,
        :exit-promise(Promise.new),
      );

      $proc.stdout.tap(-> $chunk {
        try {
          my @events = $handle.parser.feed($chunk);
          for @events -> $event {
            $handle.events.push($event);
            &!on-event($i, $event);
          }
          CATCH { default { note "Worker $i stdout tap error: {.message}" } }
        }
      });

      $proc.stderr.tap(-> $chunk {
        $handle.stderr-output ~= $chunk;
        $*ERR.print($chunk);
      });

      my $start-promise = $proc.start(:ENV(%env));
      $start-promise.then({
        try {
          my $proc-result = $start-promise.result;
          $handle.exit-code = $proc-result.exitcode;
          my @tail = $handle.parser.flush;
          for @tail -> $event {
            $handle.events.push($event);
            &!on-event($i, $event);
          }
          CATCH { default { note "Worker $i exit handler error: {.message}" } }
        }
        $handle.finished = True;
        $handle.exit-promise.keep($handle.exit-code);
      });

      @!workers.push($handle);
    }
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
