unit module BDD::Behave::Parallel::Queue;

use BDD::Behave::Parallel::Distribution;
use BDD::Behave::Parallel::EventStream;
use BDD::Behave::Parallel::Manifest;

constant Bucket = BDD::Behave::Parallel::Distribution::Bucket;

# Queue protocol: the parent process maintains a FIFO queue of buckets,
# sorted by cost descending so the largest buckets dispatch first (this
# minimizes the chance that a slow bucket ends up as a worker's last task
# while the queue is otherwise empty). Workers pull one bucket at a time
# over stdin and emit a `bucket-done` event over stdout when each completes,
# at which point the parent dispatches the next bucket. When the queue
# is empty the parent sends SHUTDOWN to each worker.
#
# Stdin command grammar (line-delimited):
#   BUCKET\t<id>\t<file>\t<loc1>,<loc2>,...
#   SHUTDOWN
#
# Stdout events from the worker (line-delimited JSON, same as the LPT
# worker) plus two queue-specific events:
#   {"type":"worker-ready"}            -- emitted once at startup
#   {"type":"bucket-done","id":"..."}  -- emitted after each bucket

class QueueScheduler is export {
  has @!queue;
  has Int $!total-dispatched = 0;
  has Int $!total-completed  = 0;

  method enqueue(Bucket $b --> Nil) {
    @!queue.push: $b;
  }

  method enqueue-sorted(@buckets --> Nil) {
    @!queue.append: @buckets.sort({ $^b.cost <=> $^a.cost }).list;
  }

  method next-bucket(--> Bucket) {
    return Bucket if @!queue.elems == 0;
    $!total-dispatched++;
    @!queue.shift;
  }

  method mark-complete(--> Nil) {
    $!total-completed++;
  }

  method has-pending(--> Bool) {
    @!queue.elems > 0;
  }

  method pending-count(--> Int) {
    @!queue.elems;
  }

  method dispatched(--> Int) { $!total-dispatched }
  method completed(--> Int)  { $!total-completed  }

  method all-complete(--> Bool) {
    @!queue.elems == 0 && $!total-dispatched == $!total-completed;
  }
}

our sub format-bucket-command(Bucket $b --> Str) is export {
  my $locs = $b.locations.join(',');
  "BUCKET\t{$b.id}\t{$b.file}\t$locs";
}

our sub parse-bucket-command(Str $line --> Hash) is export {
  return %( :type<unknown> ) unless $line.defined;
  my $trimmed = $line.chomp;
  return %( :type<shutdown> ) if $trimmed eq 'SHUTDOWN';
  return %( :type<unknown> ) unless $trimmed.starts-with('BUCKET');

  my @parts = $trimmed.split("\t");
  return %( :type<unknown> ) unless @parts.elems >= 4;

  my @locations = @parts[3].split(',').grep(*.chars).list;
  %(
    :type<bucket>,
    :id(@parts[1]),
    :file(@parts[2]),
    :locations(@locations),
  );
}

class QueueWorkerHandle is export {
  has Int          $.index is required;
  has Proc::Async  $.proc  is required;
  has Promise      $.exit-promise is required;
  has JsonLineParser $.parser = JsonLineParser.new;
  has Bool         $.finished is rw = False;
  has Int          $.exit-code is rw = 0;
  has Bool         $.shutdown-sent is rw = False;
}

class QueueWorkerPool is export {
  has Int      $.worker-count   is required;
  has @.worker-argv             is required;
  has @.spec-files;
  has %.base-env;
  has IO::Path $.coverage-log-dir;
  has Bool $.coverage-counts = False;
  has &.on-event   = sub ($wi, $event) { };
  has &.on-ready   = sub ($wi)         { };
  has &.on-done    = sub ($wi, $id)    { };

  has Lock $!io-lock = Lock.new;
  has QueueWorkerHandle @!workers;

  method launch(--> Nil) {
    for ^$!worker-count -> $i {
      my @argv = @!worker-argv.Slip;
      @argv.push: '--queue-worker';
      @argv.append: @!spec-files;

      my %env = |%!base-env;
      %env<BEHAVE_WORKER_INDEX> = $i.Str;
      %env<BEHAVE_WORKER_COUNT> = $!worker-count.Str;

      if $!coverage-log-dir.defined {
        %env<MVM_COVERAGE_LOG>
          = $!coverage-log-dir.add("worker-$i.raw").absolute;
        %env<MVM_COVERAGE_CONTROL> = $!coverage-counts ?? '2' !! '0';
      }

      my $proc = Proc::Async.new(:w, |@argv);

      my $handle = QueueWorkerHandle.new(
        :index($i),
        :$proc,
        :exit-promise(Promise.new),
      );

      # The race we are avoiding: Proc::Async's start-promise resolves
      # when the *process* exits, but stdout tap callbacks are scheduled
      # on the thread pool and may not have run yet. If we let wait-all
      # return as soon as the process exit fires, late chunks can dispatch
      # event handlers after the parent has already moved on to summary
      # rendering, dropping example counts. The fix is to delay keeping
      # exit-promise until the stdout supply itself signals `done` (which
      # only happens after every chunk has been delivered to our tap).
      my $stdout-done = Promise.new;
      my $stderr-done = Promise.new;

      $proc.stdout.tap(
        -> $chunk {
          try {
            my @events = $handle.parser.feed($chunk);
            for @events -> $event {
              self!handle-worker-event($i, $event);
            }
            CATCH { default { note "Queue worker $i stdout tap error: {.message}" } }
          }
        },
        done => { $stdout-done.keep },
        quit => { $stdout-done.keep },
      );

      $proc.stderr.tap(
        -> $chunk { $*ERR.print($chunk) },
        done => { $stderr-done.keep },
        quit => { $stderr-done.keep },
      );

      my $start-promise = $proc.start(:ENV(%env));
      Promise.allof($start-promise, $stdout-done, $stderr-done).then({
        try {
          my $proc-result = $start-promise.result;
          # Fold a signal death (exitcode 0, signal set) to 128+N so crash
          # checks downstream never read it as success.
          $handle.exit-code = $proc-result.signal
            ?? 128 + $proc-result.signal
            !! $proc-result.exitcode;
          note "Queue worker $i died with signal {$proc-result.signal}"
            if $proc-result.signal;
          my @tail = $handle.parser.flush;
          for @tail -> $event {
            self!handle-worker-event($i, $event);
          }
          CATCH { default { note "Queue worker $i exit handler error: {.message}" } }
        }
        $handle.finished = True;
        $handle.exit-promise.keep($handle.exit-code);
      });

      @!workers.push: $handle;
    }
  }

  method !handle-worker-event(Int $i, %event --> Nil) {
    my $type = (%event<type> // '').Str;
    given $type {
      when 'worker-ready' { &!on-ready($i) }
      when 'bucket-done'  { &!on-done($i, (%event<id> // '').Str) }
      default             { &!on-event($i, %event) }
    }
  }

  method send-bucket(Int $i, $bucket --> Nil) {
    return unless 0 <= $i < @!workers.elems;
    my $handle = @!workers[$i];
    return if $handle.finished;
    return if $handle.shutdown-sent;
    my $cmd = format-bucket-command($bucket) ~ "\n";
    $!io-lock.protect: {
      try {
        $handle.proc.print($cmd);
        CATCH { default { note "Queue worker $i: failed to send bucket: {.message}" } }
      }
    }
  }

  method send-shutdown(Int $i --> Nil) {
    return unless 0 <= $i < @!workers.elems;
    my $handle = @!workers[$i];
    return if $handle.finished;
    return if $handle.shutdown-sent;
    $handle.shutdown-sent = True;
    $!io-lock.protect: {
      try {
        # Write SHUTDOWN and then close the stdin pipe so the worker reads
        # EOF if it's already past the SHUTDOWN line. close-stdin must NOT
        # race with the worker's own exit (which would also close the pipe
        # from the other side and may drop in-flight stdout events on some
        # OSes), so we await the worker's read by giving it a beat.
        $handle.proc.print("SHUTDOWN\n");
        CATCH { default { note "Queue worker $i: failed to send shutdown: {.message}" } }
      }
    }
  }

  method shutdown-all(--> Nil) {
    for ^$!worker-count -> $i {
      self.send-shutdown($i);
    }
  }

  method wait-all(--> Nil) {
    await Promise.allof(@!workers.map(*.exit-promise));
  }

  method workers(--> List) { @!workers.List }
}
