unit module BDD::Behave::Parallel;

use BDD::Behave::Parallel::Distribution;
use BDD::Behave::Parallel::WorkerPool;
use BDD::Behave::Parallel::Queue;
use BDD::Behave::Parallel::Manifest;
use BDD::Behave::Parallel::EventStream;
use BDD::Behave::SpecRegistry;
use BDD::Behave::SpecLoader;
use BDD::Behave::Runner;
use BDD::Behave::Formatter;
use BDD::Behave::Failures;
use BDD::Behave::Failure;
use BDD::Behave::Colors;
use BDD::Behave::Coverage;

need BDD::Behave::SpecTree;

constant Suite        = BDD::Behave::SpecTree::Suite;
constant ExampleGroup = BDD::Behave::SpecTree::ExampleGroup;
constant Example      = BDD::Behave::SpecTree::Example;
constant RunResult    = BDD::Behave::Runner::RunResult;

class ParallelRunOptions is export {
  has Int      $.worker-count is required;
  has @.spec-files;
  has @.worker-argv;
  has @.discovery-argv;
  has %.base-env;
  has BDD::Behave::Formatter $.formatter is required;
  has Bool     $.verbose = False;
  has Int      $.seed;
  has Str      $.order = 'random';
  has Str      $.seed-mode = 'xor';
  has Bool     $.progress-total = False;
  has @.include-tags;
  has @.exclude-tags;
  has @.example-patterns;
  has @.only-locations;
  has Bool     $.fail-fast-any = False;
  has Bool     $.discovery-in-process = False;
  has Str      $.parallel-mode = 'lpt';
  has Int      $.parallel-retry = 0;
  has IO::Path $.coverage-log-dir = IO::Path;
}

sub discover-suites(@spec-files --> List) is export {
  my $registry = BDD::Behave::SpecRegistry::registry();
  my @suites;
  my @load-errors;
  for @spec-files -> $file {
    try {
      BDD::Behave::SpecLoader::load-spec-file($file);
      CATCH {
        default {
          @load-errors.push: %( :$file, :message(.message) );
        }
      }
    }
    my $suite = $registry.suite-for-file($file.IO);
    @suites.push($suite) if $suite.defined;
  }
  (@suites.List, @load-errors.List).List;
}

sub current-include-flags(--> List) is export {
  (gather for $*REPO.repo-chain.reverse {
    take '-I' ~ .prefix.absolute if $_ ~~ CompUnit::Repository::FileSystem;
  }).List;
}

sub default-discovery-argv(--> List) is export {
  ('raku', |current-include-flags(), $*PROGRAM-NAME).List;
}

sub discover-suites-subprocess(
  @spec-files,
  :@discovery-argv,
  :%base-env,
  --> List
) is export {
  my @suites;
  my @load-errors;

  return (@suites.List, @load-errors.List).List unless @spec-files.elems;

  my @argv = (@discovery-argv.elems ?? @discovery-argv.list !! default-discovery-argv()).list;
  @argv.push: '--no-config';
  @argv.push: '--list-examples';
  @argv.push: '--list-examples-format=json';
  @argv.append: @spec-files.map(*.Str);

  my %env = %base-env.elems ?? %base-env.Hash !! %*ENV.Hash;
  %env<BEHAVE_DISABLE_CONFIG> = '1';
  %env<MVM_COVERAGE_LOG>:delete;
  %env<MVM_COVERAGE_CONTROL>:delete;
  %env<BEHAVE_COVERAGE_LOG>:delete;

  my $proc = Proc::Async.new(|@argv);
  my $stdout = '';
  my $stderr = '';
  $proc.stdout.tap(-> $chunk { $stdout ~= $chunk });
  $proc.stderr.tap(-> $chunk { $stderr ~= $chunk });

  my $result;
  try {
    my $promise = $proc.start(:ENV(%env));
    $result = await $promise;
    CATCH {
      default {
        for @spec-files -> $f {
          @load-errors.push: %( file => $f.Str, message => "discovery subprocess failed: {.message}" );
        }
        return (@suites.List, @load-errors.List).List;
      }
    }
  }

  if $result.exitcode > 1 {
    my $msg = "discovery subprocess exited with code {$result.exitcode}";
    $msg ~= ": $stderr" if $stderr.chars;
    for @spec-files -> $f {
      @load-errors.push: %( file => $f.Str, :message($msg) );
    }
    return (@suites.List, @load-errors.List).List;
  }

  my %doc;
  try {
    %doc = BDD::Behave::Coverage::parse-baseline-json($stdout);
    CATCH {
      default {
        for @spec-files -> $f {
          @load-errors.push: %( file => $f.Str, message => "discovery subprocess returned invalid JSON: {.message}" );
        }
        return (@suites.List, @load-errors.List).List;
      }
    }
  }

  for ((%doc<suites> // ()).list) -> %node {
    my $suite = rebuild-suite(%node);
    @suites.push: $suite if $suite.defined;
  }

  for ((%doc<load-errors> // ()).list) -> %err {
    @load-errors.push: %(
      file    => (%err<file>    // '').Str,
      message => (%err<message> // '').Str,
    );
  }

  (@suites.List, @load-errors.List).List;
}

sub rebuild-suite(%node) {
  my %meta = json-metadata-to-raku(%node<metadata> // %());
  my $suite = Suite.new(
    :description((%node<description> // '').Str),
    :file((%node<file> // '').IO),
    :line((%node<line> // 0).Int),
    :metadata(%meta),
  );
  for ((%node<children> // ()).list) -> %child {
    rebuild-child-into($suite, %child);
  }
  $suite;
}

sub rebuild-child-into($parent, %node) {
  my $type = (%node<type> // '').Str;
  my %meta = json-metadata-to-raku(%node<metadata> // %());
  given $type {
    when 'group' {
      my $group = ExampleGroup.new(
        :description((%node<description> // '').Str),
        :file((%node<file> // '').IO),
        :line((%node<line> // 0).Int),
        :metadata(%meta),
      );
      $parent.add-child($group);
      for ((%node<children> // ()).list) -> %child {
        rebuild-child-into($group, %child);
      }
    }
    when 'example' {
      my $example = Example.new(
        :description((%node<description> // '').Str),
        :file((%node<file> // '').IO),
        :line((%node<line> // 0).Int),
        :metadata(%meta),
        :block(sub { }),
      );
      $example.pending = ?(%node<pending>);
      $parent.add-child($example);
    }
  }
}

sub json-metadata-to-raku(%raw --> Hash) {
  my %m;
  for %raw.kv -> $k, $v {
    %m{$k} = $v;
  }
  %m;
}

sub locations-for-buckets(@buckets --> List) is export {
  my @all;
  for @buckets -> $b {
    @all.append: $b.locations.list;
  }
  @all.List;
}

sub collect-filtered-buckets(
  @suites,
  :@include-tags,
  :@exclude-tags,
  :@example-patterns,
  :@only-locations,
  --> List
) is export {
  my @all-buckets;
  for @suites -> $suite {
    @all-buckets.append: collect-buckets($suite).list;
  }

  my @filtered = @all-buckets.map(-> $b {
    my @kept = $b.examples.grep({
      example-passes-filters($_, :@include-tags, :@exclude-tags, :@example-patterns, :@only-locations);
    });
    if @kept.elems == $b.examples.elems {
      $b;
    } elsif @kept.elems == 0 {
      Nil;
    } else {
      my $new = BDD::Behave::Parallel::Distribution::Bucket.new(
        :id($b.id),
        :file($b.file),
      );
      $new.add($_) for @kept;
      $new.serial = $b.serial;
      $new;
    }
  }).grep(*.defined);

  @filtered.List;
}

sub build-worker-manifests(
  @suites,
  Int $worker-count,
  :@include-tags,
  :@exclude-tags,
  :@example-patterns,
  :@only-locations,
  Str :$seed-mode = 'xor',
  Int :$seed,
  --> Hash
) is export {
  my @filtered = collect-filtered-buckets(
    @suites,
    :@include-tags,
    :@exclude-tags,
    :@example-patterns,
    :@only-locations,
  );

  my ($parallel-buckets, $serial-buckets) = split-parallel-and-serial(@filtered);

  my @parallel-assignments = $seed-mode eq 'stable'
    ?? distribute-stable($parallel-buckets, $worker-count, $seed // 0)
    !! distribute-lpt($parallel-buckets, $worker-count);

  my @parallel-manifests;
  for ^$worker-count -> $i {
    my @locs;
    for @parallel-assignments[$i].list -> $b {
      @locs.append: $b.locations.list;
    }
    @parallel-manifests.push: @locs;
  }

  my @serial-locations;
  for $serial-buckets.list -> $b {
    @serial-locations.append: $b.locations.list;
  }

  %(
    parallel-manifests => @parallel-manifests.List,
    serial-locations   => @serial-locations.List,
    parallel-count     => $parallel-buckets.list.map(*.cost).sum,
    serial-count       => $serial-buckets.list.map(*.cost).sum,
  );
}

sub example-passes-filters(Example $example, :@include-tags, :@exclude-tags, :@example-patterns, :@only-locations --> Bool) {
  my @tags = $example.effective-tags;
  if @exclude-tags.elems && @tags.first({ $_ ∈ @exclude-tags }).defined {
    return False;
  }
  if @include-tags.elems && !@tags.first({ $_ ∈ @include-tags }).defined {
    return False;
  }
  if @example-patterns.elems {
    my $desc = nested-description($example);
    my $matched = False;
    for @example-patterns -> $pat {
      if pattern-matches($desc, $pat) {
        $matched = True;
        last;
      }
    }
    return False unless $matched;
  }
  if @only-locations.elems {
    my $matched = False;
    my $ex-loc = "{$example.file.absolute}:{$example.line}";
    for @only-locations -> $loc {
      if location-matches($ex-loc, $loc) {
        $matched = True;
        last;
      }
      for $example.ancestry -> $node {
        next unless $node ~~ ExampleGroup;
        if location-matches("{$node.file.absolute}:{$node.line}", $loc) {
          $matched = True;
          last;
        }
      }
      last if $matched;
    }
    return False unless $matched;
  }
  True;
}

sub nested-description(Example $example --> Str) {
  my @parts = $example.ancestry.grep(ExampleGroup).map(*.description);
  @parts.push($example.description);
  @parts.join(' ');
}

sub pattern-matches(Str $description, Str $pattern --> Bool) {
  if $pattern.chars > 2 && $pattern.starts-with('/') && $pattern.ends-with('/') {
    my $body = $pattern.substr(1, $pattern.chars - 2);
    my $rx = / <{ $body }> /;
    return so $description.match($rx);
  }
  $description.contains($pattern);
}

sub location-matches(Str $ex-loc, Str $pattern --> Bool) {
  return False unless $pattern.contains(':');
  my $idx = $pattern.rindex(':');
  my $pat-path = $pattern.substr(0, $idx);
  my $pat-line = $pattern.substr($idx + 1);
  my $ex-idx = $ex-loc.rindex(':');
  return False unless $ex-idx.defined;
  my $ex-path = $ex-loc.substr(0, $ex-idx);
  my $ex-line = $ex-loc.substr($ex-idx + 1);
  return False unless $ex-line eq $pat-line;
  return True if $ex-path eq $pat-path;
  return True if $ex-path.IO.absolute eq $pat-path.IO.absolute;
  return True if $ex-path.ends-with('/' ~ $pat-path);
  return True if $ex-path.IO.basename eq $pat-path;
  False;
}

class ShardRetryRecord is export {
  has Int $.worker      is required;
  has Int $.attempts    is required;
  has Int $.final-exit  is required;
  has Str $.outcome     is required;
  has @.crash-codes;
}

class ParallelRunResult is export {
  has Int $.total   is rw = 0;
  has Int $.passed  is rw = 0;
  has Int $.failed  is rw = 0;
  has Int $.pending is rw = 0;
  has Int $.skipped is rw = 0;
  has @.failures;
  has @.load-errors;
  has @.retry-records;
  has @.shard-retry-records;
  has @.executed-locations;
  has @.failed-locations;
  has @.timed-examples;
  has @.memory-records;
  has @.benchmark-summaries;
  has Int $.exit-code is rw = 0;

  method success(--> Bool) { $!failed == 0 && @!load-errors.elems == 0 && $!exit-code == 0 }
}

sub run-parallel-isolated-impl(
  ParallelRunOptions $opts,
  ParallelRunResult $result,
  @suites,
  --> ParallelRunResult
) {
  my @filtered = collect-filtered-buckets(
    @suites,
    :include-tags($opts.include-tags),
    :exclude-tags($opts.exclude-tags),
    :example-patterns($opts.example-patterns),
    :only-locations($opts.only-locations),
  );

  my @file-buckets = coalesce-by-file(@filtered);

  if $opts.progress-total {
    my $total = @file-buckets.map(*.cost).sum;
    $opts.formatter.set-total($total);
  }

  return $result unless @file-buckets.elems;

  my $manifest-dir = $*TMPDIR.add("behave-parallel-isolated-{$*PID}-{(now * 1e6).Int}");
  $manifest-dir.mkdir;

  LEAVE {
    if $manifest-dir.defined && $manifest-dir.e && $manifest-dir.d {
      for $manifest-dir.dir -> $f { $f.unlink if $f.f }
      $manifest-dir.rmdir;
    }
  }

  my Lock $event-lock .= new;

  # Build one job per spec file (manifest + argv + env), then feed them through
  # a closed Channel to a fixed pool of exactly worker-count threads. Each
  # thread owns a stable slot (0 .. N-1) that it exports as BEHAVE_WORKER_INDEX
  # and pulls one job at a time, so concurrently-running files always hold
  # distinct indices — user code can key a per-worker resource (e.g. a database
  # `myapp_test_{Worker.id}`) off the index with only N to provision. Using a
  # fixed N-thread pool (not one `start` per file) is essential: one start per
  # file would pile up worker-count-blocked threads and starve the thread pool
  # that Proc::Async needs to drain worker stdout, deadlocking the run.
  my $queue = Channel.new;
  my $file-index = 0;

  for @file-buckets -> $bucket {
    my $idx          = $file-index++;
    my $file         = $bucket.file;
    my @locations    = $bucket.locations.list;
    my $manifest-path = $manifest-dir.add("file-$idx.manifest");
    write-manifest($manifest-path, @locations);

    my @argv = $opts.worker-argv.Slip;
    @argv.push: '--worker-manifest', $manifest-path.absolute;
    @argv.push: $file;

    my %env = |$opts.base-env;
    %env<BEHAVE_WORKER_COUNT> = $opts.worker-count.Str;

    if $opts.coverage-log-dir.defined {
      %env<MVM_COVERAGE_LOG>
        = $opts.coverage-log-dir.add("isolated-$idx.raw").absolute;
      %env<MVM_COVERAGE_CONTROL> = '2';
    }

    $queue.send({ :$idx, :$file, :@argv, :%env });
  }
  $queue.close;

  my @promises;
  for ^$opts.worker-count -> $slot {
    @promises.push: start {
      loop {
        my %job = $queue.receive;
        CATCH { when X::Channel::ReceiveOnClosed { last } }

        my @argv = %job<argv>.list;
        my %env  = %job<env>.hash;
        my $idx  = %job<idx>;
        my $file = %job<file>;

        %env<BEHAVE_WORKER_INDEX> = $slot.Str;

        my $proc   = Proc::Async.new(|@argv);
        my $parser = JsonLineParser.new;

        $proc.stdout.tap(-> $chunk {
          for $parser.feed($chunk) -> $event {
            $event-lock.protect: {
              handle-event($opts.formatter, $result, $idx, $event, @suites);
            }
          }
        });
        $proc.stderr.tap(-> $chunk {
          $event-lock.protect: { $*ERR.print($chunk) }
        });

        my $proc-result = await $proc.start(:ENV(%env));

        for $parser.flush -> $event {
          $event-lock.protect: {
            handle-event($opts.formatter, $result, $idx, $event, @suites);
          }
        }

        if $proc-result.exitcode > 1 {
          $event-lock.protect: {
            $result.exit-code = 1;
            note red("Isolated worker for $file exited with code {$proc-result.exitcode}");
          }
        }
      }
    };
  }

  await Promise.allof(@promises);
  $result;
}

sub run-parallel-queue-impl(
  ParallelRunOptions $opts,
  ParallelRunResult $result,
  @suites,
  --> ParallelRunResult
) {
  my @filtered = collect-filtered-buckets(
    @suites,
    :include-tags($opts.include-tags),
    :exclude-tags($opts.exclude-tags),
    :example-patterns($opts.example-patterns),
    :only-locations($opts.only-locations),
  );

  my ($parallel-buckets, $serial-buckets) = split-parallel-and-serial(@filtered);
  my @parallel = $parallel-buckets.list;
  my @serial   = $serial-buckets.list;

  if $opts.progress-total {
    my $total = @parallel.map(*.cost).sum + @serial.map(*.cost).sum;
    $opts.formatter.set-total($total);
  }

  if @parallel.elems {
    my $worker-count = $opts.worker-count min @parallel.elems;
    my $scheduler = BDD::Behave::Parallel::Queue::QueueScheduler.new;
    $scheduler.enqueue-sorted(@parallel);

    my Lock $dispatch-lock .= new;
    my Lock $event-lock    .= new;
    my $pool;

    my &dispatch-or-shutdown = sub (Int $wi --> Nil) {
      my $next;
      $dispatch-lock.protect: {
        $next = $scheduler.next-bucket;
      }
      if $next.defined {
        $pool.send-bucket($wi, $next);
      } else {
        $pool.send-shutdown($wi);
      }
    }

    $pool = BDD::Behave::Parallel::Queue::QueueWorkerPool.new(
      :$worker-count,
      :worker-argv($opts.worker-argv),
      :spec-files($opts.spec-files.map(*.Str).List),
      :base-env(%(|$opts.base-env)),
      :coverage-log-dir($opts.coverage-log-dir),
      # Tap callbacks for every worker fire on the thread pool, so
      # several can be processing events concurrently. handle-event
      # mutates $result.total / $result.passed / ... and writes to the
      # parent formatter; both are unsynchronized state, so we serialize
      # all per-event work behind a single lock.
      :on-event(sub ($wi, $event) {
        $event-lock.protect: {
          handle-event($opts.formatter, $result, $wi, $event, @suites);
        }
      }),
      :on-ready(&dispatch-or-shutdown),
      :on-done(sub ($wi, $id) {
        $dispatch-lock.protect: { $scheduler.mark-complete }
        dispatch-or-shutdown($wi);
      }),
    );

    $pool.launch;
    $pool.wait-all;
    for $pool.workers -> $w {
      if $w.exit-code > 1 {
        $result.exit-code = 1;
        note red("Queue worker {$w.index} exited with code {$w.exit-code}");
      }
    }
  }

  if @serial.elems {
    my $serial-dir = $*TMPDIR.add("behave-parallel-queue-serial-{$*PID}-{(now * 1e6).Int}");
    $serial-dir.mkdir;
    LEAVE {
      if $serial-dir.defined && $serial-dir.e && $serial-dir.d {
        for $serial-dir.dir -> $f { $f.unlink if $f.f }
        $serial-dir.rmdir;
      }
    }

    my @serial-locations;
    for @serial -> $b { @serial-locations.append: $b.locations.list }

    my $serial-manifest-path = $serial-dir.add('serial.manifest');
    write-manifest($serial-manifest-path, @serial-locations);
    my @files = files-from-manifest(@serial-locations);
    my @argv = $opts.worker-argv.Slip;
    @argv.push: '--worker-manifest', $serial-manifest-path.absolute;
    @argv.append: @files;

    my %env = |$opts.base-env;
    %env<BEHAVE_WORKER_INDEX> = '0';
    %env<BEHAVE_WORKER_COUNT> = '1';

    if $opts.coverage-log-dir.defined {
      %env<MVM_COVERAGE_LOG>
        = $opts.coverage-log-dir.add('serial.raw').absolute;
      %env<MVM_COVERAGE_CONTROL> = '2';
    }

    my $proc = Proc::Async.new(|@argv);
    my $parser = JsonLineParser.new;

    $proc.stdout.tap(-> $chunk {
      for $parser.feed($chunk) -> $event {
        handle-event($opts.formatter, $result, -1, $event, @suites);
      }
    });
    $proc.stderr.tap(-> $chunk {
      $*ERR.print($chunk);
    });

    my $start = $proc.start(:ENV(%env));
    my $proc-result = await $start;
    for $parser.flush -> $event {
      handle-event($opts.formatter, $result, -1, $event, @suites);
    }
    if $proc-result.exitcode > 1 {
      $result.exit-code = 1;
      note red("Serial worker exited with code {$proc-result.exitcode}");
    }
  }

  $result;
}

sub run-parallel(
  ParallelRunOptions $opts,
  --> ParallelRunResult
) is export {
  my $result = ParallelRunResult.new;

  my $disco = $opts.discovery-in-process
    ?? discover-suites($opts.spec-files)
    !! discover-suites-subprocess(
         $opts.spec-files,
         :discovery-argv($opts.discovery-argv),
         :base-env(%(|$opts.base-env)),
       );
  my @suites      = $disco[0].list;
  my @load-errors = $disco[1].list;
  $result.load-errors.append: @load-errors;

  my $mode = ($opts.parallel-mode // 'lpt').lc;

  if $mode eq 'queue' {
    return run-parallel-queue-impl($opts, $result, @suites);
  }

  if $mode eq 'isolated' {
    return run-parallel-isolated-impl($opts, $result, @suites);
  }

  my %plan = build-worker-manifests(
    @suites,
    $opts.worker-count,
    :include-tags($opts.include-tags),
    :exclude-tags($opts.exclude-tags),
    :example-patterns($opts.example-patterns),
    :only-locations($opts.only-locations),
    :seed-mode($opts.seed-mode),
    :seed($opts.seed),
  );

  my @parallel-manifests = %plan<parallel-manifests>.list;
  my @serial-locations   = %plan<serial-locations>.list;

  if $opts.progress-total {
    my $total = (%plan<parallel-count> // 0).Int + (%plan<serial-count> // 0).Int;
    $opts.formatter.set-total($total);
  }

  my $manifest-dir = $*TMPDIR.add("behave-parallel-{$*PID}-{(now * 1e6).Int}");
  $manifest-dir.mkdir;

  LEAVE {
    if $manifest-dir.defined && $manifest-dir.e && $manifest-dir.d {
      for $manifest-dir.dir -> $f { $f.unlink if $f.f }
      $manifest-dir.rmdir;
    }
  }

  if @parallel-manifests.grep({ .elems }).elems {
    my Lock $event-lock .= new;
    my $pool = WorkerPool.new(
      :worker-count($opts.worker-count),
      :worker-argv($opts.worker-argv),
      :base-env(%(|$opts.base-env)),
      :manifest-dir($manifest-dir),
      :coverage-log-dir($opts.coverage-log-dir),
      :retry-count($opts.parallel-retry),
      # Tap callbacks fire on the thread pool — N workers can dispatch
      # concurrently into handle-event, which mutates $result.* and
      # writes to the parent formatter. Serialize both.
      :on-event(sub ($wi, $event) {
        $event-lock.protect: {
          handle-event($opts.formatter, $result, $wi, $event, @suites);
        }
      }),
      :on-shard-retry(sub ($wi, $attempt, $exit-code) {
        $event-lock.protect: {
          note yellow("Worker $wi crashed with exit $exit-code; retrying (attempt $attempt of {$opts.parallel-retry + 1})");
        }
      }),
    );
    $pool.launch(@parallel-manifests);
    $pool.wait-all;
    for $pool.workers -> $w {
      if $w.attempt > 1 {
        my $outcome = $w.exit-code > 1 ?? 'crashed' !! 'recovered';
        $result.shard-retry-records.push: ShardRetryRecord.new(
          :worker($w.index),
          :attempts($w.attempt),
          :final-exit($w.exit-code),
          :$outcome,
          :crash-codes($w.crash-codes.list),
        );
      }
      if $w.exit-code > 1 {
        $result.exit-code = 1;
        note red("Worker {$w.index} exited with code {$w.exit-code} (after {$w.attempt} attempt{$w.attempt == 1 ?? '' !! 's'})");
      }
    }
  }

  if @serial-locations.elems {
    my $serial-manifest-path = $manifest-dir.add('serial.manifest');
    write-manifest($serial-manifest-path, @serial-locations);
    my @files = files-from-manifest(@serial-locations);
    my @argv = $opts.worker-argv.Slip;
    @argv.push: '--worker-manifest', $serial-manifest-path.absolute;
    @argv.append: @files;

    my %env = |$opts.base-env;
    %env<BEHAVE_WORKER_INDEX> = '0';
    %env<BEHAVE_WORKER_COUNT> = '1';

    if $opts.coverage-log-dir.defined {
      %env<MVM_COVERAGE_LOG>
        = $opts.coverage-log-dir.add('serial.raw').absolute;
      %env<MVM_COVERAGE_CONTROL> = '2';
    }

    my $proc = Proc::Async.new(|@argv);
    my $parser = JsonLineParser.new;

    $proc.stdout.tap(-> $chunk {
      for $parser.feed($chunk) -> $event {
        handle-event($opts.formatter, $result, -1, $event, @suites);
      }
    });
    $proc.stderr.tap(-> $chunk {
      $*ERR.print($chunk);
    });

    my $start = $proc.start(:ENV(%env));
    my $proc-result = await $start;
    for $parser.flush -> $event {
      handle-event($opts.formatter, $result, -1, $event, @suites);
    }
    if $proc-result.exitcode > 1 {
      $result.exit-code = 1;
      note red("Serial worker exited with code {$proc-result.exitcode}");
    }
    $serial-manifest-path.unlink if $serial-manifest-path.e;
  }

  $result;
}

sub handle-event($formatter, ParallelRunResult $result, Int $worker, %event, @suites) {
  my $type = %event<type> // 'unknown';
  given $type {
    when 'suite-start' {
      my $suite = lookup-suite(@suites, %event<id>);
      $formatter.suite-start($suite, :multi-file(@suites.elems > 1)) if $suite.defined;
    }
    when 'suite-end' {
      my $suite = lookup-suite(@suites, %event<id>);
      $formatter.suite-end($suite) if $suite.defined;
    }
    when 'group-start' {
      my $group = lookup-group(@suites, %event<id>);
      $formatter.group-start($group) if $group.defined;
    }
    when 'group-end' {
      my $group = lookup-group(@suites, %event<id>);
      $formatter.group-end($group) if $group.defined;
    }
    when 'group-around-skipped' {
      my $group = lookup-group(@suites, %event<id>);
      $formatter.group-around-skipped($group) if $group.defined;
    }
    when 'example-start' {
      my $example = resolve-example(@suites, %event);
      if $example.defined {
        $example.started-at = now;
        $formatter.example-start($example, :auto(?%event<auto>));
      }
    }
    when 'example-auto-description' {
      my $example = resolve-example(@suites, %event);
      $formatter.example-auto-description($example, :description(%event<description> // ''))
        if $example.defined;
    }
    when 'example-pass' {
      my $example = resolve-example(@suites, %event);
      if $example.defined {
        $example.duration = (%event<duration> // 0).Real;
        $formatter.example-pass($example);
        $result.executed-locations.push("{$example.file.absolute}:{$example.line}");
      }
      $result.total++;
      $result.passed++;
    }
    when 'example-fail' {
      my $example = resolve-example(@suites, %event);
      my %failure-info = (
        description => (%event<failure-description> // ($example.defined ?? $example.description !! '')),
        file        => (%event<failure-file> // ($example.defined ?? $example.file.absolute !! '')),
        line        => (%event<failure-line> // ($example.defined ?? $example.line !! 0)),
      );
      with %event<exception-message> {
        %failure-info<exception-message> = $_;
      }
      with %event<exception-backtrace> {
        %failure-info<exception-backtrace> = $_;
      }
      if $example.defined {
        $example.duration = (%event<duration> // 0).Real;
        $formatter.example-fail($example, :%failure-info);
        my $loc = "{$example.file.absolute}:{$example.line}";
        $result.executed-locations.push($loc);
        $result.failed-locations.push($loc);
      } else {
        my $f = %failure-info<file>.Str;
        my $l = %failure-info<line>.Int;
        $result.failed-locations.push("$f:$l") if $f.chars && $l;
      }
      $result.total++;
      $result.failed++;
      $result.failures.push: %failure-info;

      my $desc = %failure-info<description>;
      my @event-failures = (%event<failures> // ()).list;
      for @event-failures -> %f {
        my $msg = (%f<message> // '').Str;
        if !$msg.chars {
          my $given    = (%f<given>    // '').Str;
          my $expected = (%f<expected> // '').Str;
          if $given.chars || $expected.chars {
            my $op = (%f<negated> // False) ?? 'not to be' !! 'to be';
            $msg = "Expected: $given\n$op: $expected";
          }
        }
        Failures.list.push: Failure.new(
          :file((%f<file> // '').Str),
          :line((%f<line> // 0).Int),
          :message($msg.chars ?? $msg !! Str),
          :aggregation-label(
            ((%f<aggregation-label> // '').Str.chars
              ?? %f<aggregation-label>.Str !! Str)),
          :description($desc),
        );
      }
      unless @event-failures.elems {
        with %event<exception-message> -> $msg {
          my $prefixed = $desc.chars
            ?? "exception in $desc: " ~ $msg.Str
            !! $msg.Str;

          Failures.list.push: Failure.new(
            :file(%failure-info<file>.Str),
            :line(%failure-info<line>.Int),
            :message($prefixed),
            :description($desc),
            :from-runner-exception,
          );
        }
      }
    }
    when 'example-retry' {
      my $example = resolve-example(@suites, %event);
      $formatter.example-retry(
        $example,
        :attempt((%event<attempt> // 1).Int),
        :max-attempts((%event<max-attempts> // 1).Int),
      ) if $example.defined;
    }
    when 'example-pending' {
      my $example = resolve-example(@suites, %event);
      $formatter.example-pending($example) if $example.defined;
      $result.total++;
      $result.pending++;
    }
    when 'example-skipped' {
      my $example = resolve-example(@suites, %event);
      $formatter.example-skipped($example) if $example.defined;
      $result.total++;
      $result.skipped++;
    }
    when 'example-around-skipped' {
      my $example = resolve-example(@suites, %event);
      $formatter.example-around-skipped($example) if $example.defined;
      $result.total++;
      $result.skipped++;
    }
    when 'example-slow' {
      my $example = resolve-example(@suites, %event);
      $formatter.example-slow($example, :threshold((%event<threshold> // 0).Real))
        if $example.defined;
    }
    when 'example-memory-leak' {
      my $example = resolve-example(@suites, %event);
      $formatter.example-memory-leak($example, :threshold((%event<threshold> // 0).Int))
        if $example.defined;
    }
    when 'profile-record' {
      my $example = resolve-example(@suites, %event);
      $result.timed-examples.push: %(
        example     => $example,
        description => (%event<description> // '').Str,
        duration    => (%event<duration> // 0).Real,
      );
    }
    when 'memory-record' {
      my $example = resolve-example(@suites, %event);
      $result.memory-records.push: %(
        example     => $example,
        description => (%event<description> // '').Str,
        delta       => (%event<delta>  // 0).Int,
        before      => (%event<before> // 0).Int,
        after       => (%event<after>  // 0).Int,
      );
    }
    when 'benchmark-record' {
      my $example = resolve-example(@suites, %event);
      my @timings = (%event<timings> // ()).list.map(*.Real).List;
      $result.benchmark-summaries.push: %(
        example     => $example,
        description => (%event<description> // '').Str,
        key         => (%event<key>         // '').Str,
        label       => (%event<label>.defined && (%event<label>).Str.chars
                          ?? %event<label>.Str !! Str),
        position    => (%event<position>    // 0).Int,
        runs        => (%event<runs>        // 0).Int,
        iterations  => (%event<iterations>  // 0).Int,
        timings     => @timings,
        min         => (%event<min>    // 0).Real,
        max         => (%event<max>    // 0).Real,
        mean        => (%event<mean>   // 0).Real,
        median      => (%event<median> // 0).Real,
        total       => (%event<total>  // 0).Real,
      );
    }
    when 'retry-record' {
      my $rec = BDD::Behave::Runner::RetryRecord.new(
        :description((%event<description> // '').Str),
        :location((%event<location> // '').Str),
        :attempts((%event<attempts> // 1).Int),
        :max-attempts((%event<max-attempts> // 1).Int),
        :outcome((%event<outcome> // 'pass').Str),
      );
      $result.retry-records.push($rec);
    }
    when 'load-error' {
      $result.load-errors.push: %( file => %event<file>, message => %event<message> );
    }
    when 'parse-error' {
      note red("Worker $worker emitted unparseable event: " ~ (%event<raw> // ''));
    }
    when 'run-summary' { }
    default { }
  }
}

sub lookup-suite(@suites, Str $id) {
  return Nil unless $id.defined;
  for @suites -> $suite {
    return $suite if "{$suite.file.absolute}:{$suite.line}" eq $id;
  }
  Nil;
}

sub lookup-group(@suites, Str $id) {
  return Nil unless $id.defined;
  for @suites -> $suite {
    my $hit = walk-find-group($suite, $id);
    return $hit if $hit.defined;
  }
  Nil;
}

sub walk-find-group($container, Str $id) {
  for $container.children -> $child {
    given $child {
      when ExampleGroup {
        return $child if "{$child.file.absolute}:{$child.line}" eq $id;
        my $deeper = walk-find-group($child, $id);
        return $deeper if $deeper.defined;
      }
    }
  }
  Nil;
}

sub lookup-example(@suites, Str $id) {
  return Nil unless $id.defined;
  for @suites -> $suite {
    my $hit = walk-find-example($suite, $id);
    return $hit if $hit.defined;
  }
  Nil;
}

sub resolve-example(@suites, %event) {
  my $hit = lookup-example(@suites, %event<id>);
  return $hit if $hit.defined;
  my $desc = (%event<description> // %event<failure-description> // '').Str;
  my $file = (%event<file>        // %event<failure-file>        // '').Str;
  my $line = (%event<line>        // %event<failure-line>        // 0).Int;
  return Nil unless $desc.chars || $file.chars;
  Example.new(
    :description($desc),
    :file($file.IO),
    :line($line),
    :block({ }),
  );
}

sub walk-find-example($container, Str $id) {
  for $container.children -> $child {
    given $child {
      when Example {
        return $child if "{$child.file.absolute}:{$child.line}" eq $id;
      }
      when ExampleGroup {
        my $deeper = walk-find-example($child, $id);
        return $deeper if $deeper.defined;
      }
    }
  }
  Nil;
}
