unit module BDD::Behave::Runner;

use BDD::Behave::Colors;
use BDD::Behave::Failure;
use BDD::Behave::Failures;
use BDD::Behave::Formatter;
use BDD::Behave::Formatter::Tree;
use BDD::Behave::SpecTree;

need BDD::Behave::Mock::Stub;
need BDD::Behave::LetRuntime;
need BDD::Behave::Benchmark;
need BDD::Behave::Benchmark::Baseline;
need BDD::Behave::Benchmark::Format;
need BDD::Behave::Configuration;

constant Suite = BDD::Behave::SpecTree::Suite;
constant ExampleGroup = BDD::Behave::SpecTree::ExampleGroup;
constant Example = BDD::Behave::SpecTree::Example;
constant LetRuntime = BDD::Behave::LetRuntime::LetRuntime;
constant BenchmarkResult = BDD::Behave::Benchmark::BenchmarkResult;
constant BaselineEntry   = BDD::Behave::Benchmark::Baseline::BaselineEntry;
constant Configuration   = BDD::Behave::Configuration::Configuration;

our class RunResult {
  has Int $.total   is rw = 0;
  has Int $.passed  is rw = 0;
  has Int $.failed  is rw = 0;
  has Int $.pending is rw = 0;
  has Int $.skipped is rw = 0;
  has @.errors      is rw;

  method add-pass {
    $!total++;
    $!passed++;
  }

  method add-fail($error) {
    $!total++;
    $!failed++;
    @!errors.push($error);
  }

  method add-pending {
    $!total++;
    $!pending++;
  }

  method add-skipped {
    $!total++;
    $!skipped++;
  }

  method success {
    $!failed == 0;
  }
}

our class Runner {
  has @!description-stack;
  has RunResult $.result .= new;
  has BDD::Behave::Formatter $.formatter;
  has @.include-tags;
  has @.exclude-tags;
  has @.example-patterns;
  has @.only-locations;
  has @.execution-order;
  has @.timed-examples;
  has $.aggregate-failures = False;
  has Bool $!focus-mode = False;
  has Str $.order = 'defined';
  has Int $.seed;
  has Int $!rng-state;
  has Int $.fail-fast = 0;
  has Bool $.aborted = False;
  has Real $.slow-threshold = 0;
  has Int $.profile-limit = 0;
  has Int $.memory-profile-limit = 0;
  has Int $.memory-threshold = 0;
  has Bool $.memory-profile = False;
  has @.memory-records;
  has Bool     $.benchmark-mode      = False;
  has Bool     $.benchmark-quiet     = False;
  has Int      $.benchmark-iterations = 1;
  has IO::Path $.benchmark-baseline;
  has IO::Path $.benchmark-save;
  has Real     $.benchmark-threshold = 0.10;
  has Str      $.benchmark-format    = 'text';
  has IO::Path $.benchmark-output;
  has @.benchmark-summaries;
  has @.benchmark-regressions;
  has Configuration $.config;
  has %!helper-cache;
  has @!effective-match-filters;

  submethod TWEAK {
    $!formatter //= BDD::Behave::Formatter::Tree.new;

    die "order must be 'random' or 'defined' (got: '$!order')"
      unless $!order eq 'random' | 'defined';

    die "fail-fast must be 0 or a positive integer (got: $!fail-fast)"
      if $!fail-fast < 0;

    die "slow-threshold must be 0 or positive (got: $!slow-threshold)"
      if $!slow-threshold < 0;

    die "profile-limit must be 0 or positive (got: $!profile-limit)"
      if $!profile-limit < 0;

    die "memory-profile-limit must be 0 or positive (got: $!memory-profile-limit)"
      if $!memory-profile-limit < 0;

    die "memory-threshold must be 0 or positive (got: $!memory-threshold)"
      if $!memory-threshold < 0;

    die "benchmark-iterations must be a positive integer (got: $!benchmark-iterations)"
      if $!benchmark-iterations < 1;

    die "benchmark-threshold must be 0 or positive (got: $!benchmark-threshold)"
      if $!benchmark-threshold < 0;

    die "benchmark-format must be 'text' or 'json' (got: '$!benchmark-format')"
      unless $!benchmark-format eq 'text' | 'json';

    if $!order eq 'random' {
      $!seed //= (1 .. 2_147_483_646).pick;
    }

    if $!seed.defined {
      $!rng-state = $!seed % 2_147_483_647;
      $!rng-state = 1 if $!rng-state == 0;
    }
  }

  method should-abort(--> Bool) {
    $!fail-fast > 0 && $!result.failed >= $!fail-fast;
  }

  method memory-measurement-enabled(--> Bool) {
    $!memory-profile || $!memory-profile-limit > 0 || $!memory-threshold > 0;
  }

  method measure-memory-rss(--> Int) {
    my $proc = run('ps', '-o', 'rss=', '-p', $*PID.Str, :out, :err);
    my $raw = $proc.out.slurp(:close);
    $proc.err.slurp(:close);
    return Int unless $proc.exitcode == 0;
    my $trimmed = $raw.trim;
    return Int unless $trimmed ~~ /^ \d+ $/;
    $trimmed.Int;
  }

  method advance-rng(--> Int) {
    $!rng-state = ($!rng-state * 48271) % 2_147_483_647;
    $!rng-state;
  }

  method effective-order($container --> Str) {
    if $container ~~ ExampleGroup {
      my $override = $container.effective-metadata-value('order');
      return $override if $override.defined;
    }
    $!order;
  }

  method shuffled-children($container --> List) {
    my @items = $container.children.list;
    my $effective-order = self.effective-order($container);
    return @items.List if $effective-order eq 'defined' || @items.elems <= 1;
    my @result = @items;
    for (1 ..^ @result.elems).reverse -> $i {
      my $j = self.advance-rng % ($i + 1);
      @result[$i, $j] = @result[$j, $i];
    }
    @result.List;
  }

  method run(Suite $suite) {
    $!focus-mode = self.has-focus($suite);
    self.compute-match-filters($suite);
    self.run-config-hooks('before-all');
    LEAVE { self.run-config-hooks('after-all') }
    {
      my %helpers := self.helper-snapshot;
      my $*BEHAVE-HELPERS = %helpers;
      self.run-suite($suite);
    }
    self.execute-benchmark-mode($suite) if $!benchmark-mode;
    self.print-summary;
    $!result;
  }

  method helper-snapshot(--> Hash) {
    return %() unless $!config.defined;
    my %h;
    for $!config.includes.list -> $entry {
      %!helper-cache{$entry.key} //= $entry.class.new;
      %h{$entry.key} = %!helper-cache{$entry.key};
    }
    %h;
  }

  method run-config-hooks(Str $phase, $example = Nil) {
    return unless $!config.defined;
    for $!config.hooks-for($phase).list -> $hook {
      next if $example.defined && !$hook.matches-example($example);
      try {
        ($hook.block)();
        CATCH {
          default {
            warn "Config $phase hook failed: {.message}";
          }
        }
      }
    }
  }

  method run-config-around-each(Example $example, &core) {
    return core() unless $!config.defined;
    my @arounds = $!config.hooks-for('around-each').list
      .grep({ .matches-example($example) });
    return core() unless @arounds.elems;
    my &chain = &core;
    for @arounds.reverse -> $hook {
      my &next = &chain;
      &chain = sub { ($hook.block)(&next) };
    }
    chain();
  }

  method compute-match-filters(Suite $suite) {
    @!effective-match-filters = [];
    return unless $!config.defined;
    for $!config.match-filters.list -> $pair {
      my $key = $pair.key;
      my $expected = $pair.value;
      if self.suite-has-metadata-match($suite, $key, $expected) {
        @!effective-match-filters.push: $pair;
      }
    }
  }

  method suite-has-metadata-match($node, Str $key, $expected --> Bool) {
    given $node {
      when Example {
        return self.example-metadata-matches($node, $key, $expected);
      }
      when ExampleGroup | Suite {
        for $node.children.list -> $child {
          return True if self.suite-has-metadata-match($child, $key, $expected);
        }
      }
    }
    False;
  }

  method example-metadata-matches(Example $example, Str $key, $expected --> Bool) {
    my $actual = $example.effective-metadata-value($key);
    return False unless $actual.defined;
    if $expected ~~ Bool {
      return $expected ?? ?$actual !! !$actual;
    }
    $actual eq $expected;
  }

  method execute-benchmark-mode(Suite $suite) {
    my @benchmarked = self.collect-benchmarked-examples($suite);

    if $!benchmark-iterations > 1 {
      for @benchmarked -> $example {
        for 2 .. $!benchmark-iterations {
          self.silent-rerun($example);
        }
      }
    }

    @!benchmark-summaries = self.aggregate-benchmark-summaries(@benchmarked);

    if !$!benchmark-quiet && $!benchmark-baseline.defined {
      @!benchmark-regressions =
        self.compare-with-baseline(@!benchmark-summaries, $!benchmark-baseline);
    }

    if !$!benchmark-quiet && $!benchmark-save.defined {
      self.save-benchmark-baseline(@!benchmark-summaries, $!benchmark-save);
    }
  }

  method collect-benchmarked-examples($node --> List) {
    my @found;
    given $node {
      when Example {
        @found.push: $node if $node.benchmarks.elems;
      }
      default {
        for $node.children -> $child {
          @found.append: self.collect-benchmarked-examples($child);
        }
      }
    }
    @found.List;
  }

  method silent-rerun(Example $example) {
    my $saved-result          = $!result;
    my @saved-execution-order = @!execution-order;
    my @saved-timed-examples  = @!timed-examples;
    my @saved-memory-records  = @!memory-records;

    $!result          = RunResult.new;
    @!execution-order = [];
    @!timed-examples  = [];
    @!memory-records  = [];

    my $sink = open '/dev/null', :w;
    {
      my $*OUT = $sink;
      try {
        self.handle-example($example);
        CATCH { default { } }
      }
    }
    $sink.close;

    $!result          = $saved-result;
    @!execution-order = @saved-execution-order;
    @!timed-examples  = @saved-timed-examples;
    @!memory-records  = @saved-memory-records;
  }

  method aggregate-benchmark-summaries(@examples --> List) {
    my @summaries;
    for @examples -> $example {
      my $description = self.full-nested-description($example);
      my %by-key;
      for $example.benchmarks.list -> $bench {
        %by-key{$bench.key}.push: $bench;
      }
      for %by-key.pairs.sort(*.key) -> $pair {
        my $key         = $pair.key;
        my @runs        = $pair.value.list;
        my @all-timings = @runs.map(*.timings.flat).flat.list;
        my $iterations  = [+] @runs.map(*.iterations);
        my $label       = @runs[0].label;
        my $position    = @runs[0].position;
        my %summary     = self.compute-summary(@all-timings);
        @summaries.push: %(
          example     => $example,
          description => $description,
          key         => $key,
          label       => $label,
          position    => $position,
          runs        => @runs.elems,
          iterations  => $iterations,
          timings     => @all-timings,
          |%summary,
        );
      }
    }
    @summaries.sort({ $^a<description> cmp $^b<description> || $^a<key> cmp $^b<key> }).List;
  }

  method compute-summary(@timings --> Hash) {
    return %( min => Real, max => Real, mean => Real, median => Real, total => Real )
      unless @timings.elems;
    my @sorted = @timings.sort;
    my $total  = [+] @timings;
    my $mean   = $total / @timings.elems;
    my $n      = @sorted.elems;
    my $median = $n %% 2
      ?? (@sorted[$n div 2 - 1] + @sorted[$n div 2]) / 2
      !! @sorted[$n div 2];
    %(
      min    => @sorted[0],
      max    => @sorted[*-1],
      mean   => $mean,
      median => $median,
      total  => $total,
    );
  }

  method compare-with-baseline(@summaries, IO::Path $path --> List) {
    my @entries = BDD::Behave::Benchmark::Baseline::load($path);
    my %index   = BDD::Behave::Benchmark::Baseline::index-by-key(@entries);
    my @regressions;
    for @summaries -> %s {
      my $entry = %index{%s<description>}{%s<key>};
      next unless $entry.defined;
      my $delta-pct = $entry.median == 0 ?? 0
                                          !! (%s<median> - $entry.median) / $entry.median;
      my %row = (|%s,
                 baseline-median => $entry.median,
                 baseline-mean   => $entry.mean,
                 delta-pct       => $delta-pct,
                 regression      => $delta-pct > $!benchmark-threshold);
      @regressions.push: %row;
    }
    @regressions.List;
  }

  method save-benchmark-baseline(@summaries, IO::Path $path --> Nil) {
    my BaselineEntry @entries = @summaries.map: -> %s {
      BaselineEntry.new(
        :description(%s<description>),
        :key(%s<key>),
        :iterations(%s<iterations>),
        :min(%s<min>.Real),
        :max(%s<max>.Real),
        :mean(%s<mean>.Real),
        :median(%s<median>.Real),
        :total(%s<total>.Real),
      );
    };
    BDD::Behave::Benchmark::Baseline::save($path, @entries);
  }

  method has-focus($node --> Bool) {
    return True if $node.focused;
    if $node ~~ Suite | ExampleGroup {
      for $node.children -> $child {
        return True if self.has-focus($child);
      }
    }
    False;
  }

  method run-suite(Suite $suite) {
    # A suite is a top-level container for a file
    # Walk all its children (groups and examples)
    for self.shuffled-children($suite) -> $child {
      last if self.should-abort;
      given $child {
        when ExampleGroup { self.run-group($child) if self.group-matches($child) }
        when Example      { self.handle-example($child) if self.example-matches($child) }
      }
    }
    $!aborted = True if self.should-abort;
  }

  method run-group(ExampleGroup $group) {
    $!formatter.group-start($group);

    @!description-stack.push($group.description);

    my Int $group-stub-snapshot = BDD::Behave::Mock::Stub::StubRegistry.active-count;
    LEAVE {
      BDD::Behave::Mock::Stub::StubRegistry.clear-since($group-stub-snapshot)
        if $group-stub-snapshot.defined;
    }

    my $group-skipped = $group.effective-skipped;

    if $group-skipped {
      self.run-group-body($group);
    } else {
      my @around-hooks = self.runnable-around-all-hooks($group);

      my $continuation-called = False;
      my &core = sub {
        $continuation-called = True;
        self.run-hooks($group, 'before-all');
        self.run-group-body($group);
        self.run-hooks($group, 'after-all');
      };

      if @around-hooks.elems {
        my &chain = &core;
        for @around-hooks.reverse -> $hook {
          my &next = &chain;
          &chain = sub { ($hook.callback)(&next) };
        }

        try {
          chain();
          CATCH {
            default {
              warn "around-all hook failed in {$group.description}: {.message}";
            }
          }
        }

        unless $continuation-called {
          self.mark-around-all-skipped($group);
        }
      } else {
        core();
      }
    }

    @!description-stack.pop;
    $!formatter.group-end($group);
  }

  method run-group-body(ExampleGroup $group) {
    for self.shuffled-children($group) -> $child {
      last if self.should-abort;
      given $child {
        when ExampleGroup { self.run-group($child) if self.group-matches($child) }
        when Example      { self.handle-example($child) if self.example-matches($child) }
      }
    }
  }

  method handle-example(Example $example) {
    if $example.effective-skipped {
      self.print-skipped($example);
      return;
    }

    my @lets = $example.get-metadata('lets', :default([])).flat.List;
    my $*LET-RUNTIME = LetRuntime.new(:definitions(@lets));

    my Int $stub-snapshot = BDD::Behave::Mock::Stub::StubRegistry.active-count;
    LEAVE {
      if $stub-snapshot.defined {
        BDD::Behave::Mock::Stub::StubRegistry.clear-since($stub-snapshot);
      }
    }

    my Bool $measure-memory = self.memory-measurement-enabled && !$example.pending;
    if $measure-memory {
      $example.memory-before = self.measure-memory-rss;
    }

    my @around-hooks = self.matching-around-each-hooks($example);

    my $continuation-called = False;
    my &core = sub {
      $continuation-called = True;
      self.run-each-and-example($example);
    };

    my $reached-end = False;
    if !@around-hooks.elems {
      core();
      $reached-end = True;
    } else {
      my &chain = &core;
      for @around-hooks.reverse -> $hook {
        my &next = &chain;
        &chain = sub { ($hook.callback)(&next) };
      }

      try {
        chain();
        $reached-end = True;
        CATCH {
          default {
            if $continuation-called {
              warn "around-each hook raised after example: {.message}";
              $reached-end = True;
            } else {
              $!formatter.example-start($example);
              my %failure-info = (
                description => self.full-description($example),
                file        => $example.file,
                line        => $example.line,
                exception   => $_,
              );
              $!result.add-fail(%failure-info);
              $!formatter.example-fail($example, :failure-info(%failure-info));
            }
          }
        }
      }
    }

    if !$continuation-called && $reached-end {
      self.print-around-skipped($example);
    }

    if $measure-memory && $continuation-called && !$example.pending {
      $example.memory-after = self.measure-memory-rss;
      if $example.memory-before.defined && $example.memory-after.defined {
        $example.memory-delta = $example.memory-after - $example.memory-before;
        @!memory-records.push: %(
          example     => $example,
          description => self.full-description($example),
          delta       => $example.memory-delta,
          before      => $example.memory-before,
          after       => $example.memory-after,
        );
        self.maybe-print-memory-leak($example);
      }
    }
  }

  method run-each-and-example(Example $example) {
    self.run-config-hooks('before-each', $example);
    for self.ancestor-groups($example) -> $ancestor {
      self.run-each-hooks($ancestor, 'before-each', $example);
    }

    self.run-config-around-each($example, { self.run-example($example) });

    for self.ancestor-groups($example).reverse -> $ancestor {
      self.run-each-hooks($ancestor, 'after-each', $example);
    }
    self.run-config-hooks('after-each', $example);
  }

  method matching-around-each-hooks(Example $example --> List) {
    my @hooks;
    for self.ancestor-groups($example) -> $group {
      for $group.hooks('around-each') -> $hook {
        @hooks.push($hook) if $hook.matches($example);
      }
    }
    @hooks.List;
  }

  method runnable-around-all-hooks(ExampleGroup $group --> List) {
    my @hooks;
    my @runnable;
    my $runnable-collected = False;
    for $group.hooks('around-all') -> $hook {
      if $hook.has-filter {
        unless $runnable-collected {
          @runnable = self.runnable-examples($group);
          $runnable-collected = True;
        }
        next unless @runnable.first({ $hook.matches($_) }).defined;
      }
      @hooks.push($hook);
    }
    @hooks.List;
  }

  method print-around-skipped(Example $example) {
    $!formatter.example-around-skipped($example);
    $!result.add-skipped;
  }

  method mark-around-all-skipped(ExampleGroup $group) {
    $!formatter.group-around-skipped($group);
    for self.runnable-examples($group) -> $example {
      next if $example.effective-skipped;
      $!result.add-skipped;
    }
  }

  method print-skipped(Example $example) {
    $!formatter.example-skipped($example);
    $!result.add-skipped;
  }

  method example-matches(Example $example --> Bool) {
    my @tags = $example.effective-tags;

    if @!exclude-tags.elems
       && @tags.first({ $_ ∈ @!exclude-tags }).defined {
      return False;
    }

    if $!focus-mode
       && !$example.effective-focused
       && !$example.effective-skipped {
      return False;
    }

    if @!include-tags.elems
       && !@tags.first({ $_ ∈ @!include-tags }).defined {
      return False;
    }

    return False unless self.description-matches($example);
    return False unless self.location-matches($example);
    return False unless self.config-metadata-matches($example);
    return False unless self.match-filter-matches($example);

    True;
  }

  method config-metadata-matches(Example $example --> Bool) {
    return True unless $!config.defined;
    for $!config.metadata-filters.kv -> $key, $expected {
      return False unless self.example-metadata-matches($example, $key, $expected);
    }
    for $!config.metadata-exclude-filters.kv -> $key, $expected {
      return False if self.example-metadata-matches($example, $key, $expected);
    }
    True;
  }

  method match-filter-matches(Example $example --> Bool) {
    return True unless @!effective-match-filters.elems;
    for @!effective-match-filters.list -> $pair {
      return False
        unless self.example-metadata-matches($example, $pair.key, $pair.value);
    }
    True;
  }

  method location-matches(Example $example --> Bool) {
    return True unless @!only-locations.elems;
    my $ex-loc = "{$example.file}:{$example.line}";
    for @!only-locations -> $pattern {
      return True if self.location-matches-pattern($ex-loc, $pattern);
    }
    False;
  }

  method location-matches-pattern(Str $example-loc, Str $pattern --> Bool) {
    return False unless $pattern.contains(':');
    my $idx = $pattern.rindex(':');
    my $pattern-path = $pattern.substr(0, $idx);
    my $pattern-line = $pattern.substr($idx + 1);

    my $ex-idx = $example-loc.rindex(':');
    return False unless $ex-idx.defined;
    my $example-path = $example-loc.substr(0, $ex-idx);
    my $example-line = $example-loc.substr($ex-idx + 1);

    return False unless $example-line eq $pattern-line;

    return True if $example-path eq $pattern-path;
    return True if $example-path.IO.absolute eq $pattern-path.IO.absolute;
    return True if $example-path.ends-with('/' ~ $pattern-path);
    return True if $example-path.IO.basename eq $pattern-path;
    False;
  }

  method group-matches(ExampleGroup $group --> Bool) {
    return True unless @!include-tags.elems
                    || @!exclude-tags.elems
                    || @!example-patterns.elems
                    || @!only-locations.elems
                    || $!focus-mode;

    for $group.children -> $child {
      given $child {
        when Example       { return True if self.example-matches($child) }
        when ExampleGroup  { return True if self.group-matches($child)   }
      }
    }
    False;
  }

  method description-matches(Example $example --> Bool) {
    return True unless @!example-patterns.elems;
    my $description = self.full-nested-description($example);
    for @!example-patterns -> $pattern {
      return True if self.match-pattern($description, $pattern);
    }
    False;
  }

  method full-nested-description(Example $example --> Str) {
    my @parts = $example.ancestry.grep(ExampleGroup).map(*.description);
    @parts.push($example.description);
    @parts.join(' ');
  }

  method match-pattern(Str $description, Str $pattern --> Bool) {
    if $pattern.chars > 2
       && $pattern.starts-with('/')
       && $pattern.ends-with('/') {
      my $body = $pattern.substr(1, $pattern.chars - 2);
      my $rx = / <{ $body }> /;
      return so $description.match($rx);
    }
    $description.contains($pattern);
  }

  method resolve-auto-aggregation(Example $example --> List) {
    my $value = $example.effective-metadata-value('aggregate-failures');
    $value = $!aggregate-failures unless $value.defined;

    return (False, Str).List unless $value.defined;
    return (False, Str).List if $value === False;
    if $value ~~ Str {
      return (False, Str).List unless $value.chars;
      return (True, $value).List;
    }
    (True, Str).List;
  }

  method run-example(Example $example) {
    my Bool $auto = ?$example.get-metadata('auto-description', :default(False));
    my $description = $example.description;

    if $example.pending {
      $!formatter.example-pending($example);
      $!result.add-pending;
      return;
    }

    @!execution-order.push("{$example.file}:{$example.line}");

    my ($auto-agg-on, $auto-agg-label) = self.resolve-auto-aggregation($example);

    my $initial-failure-count = Failures.list.elems;

    $!formatter.example-start($example, :$auto) unless $auto;

    my @captured-matchers;
    my $error;
    my $started = now;
    $example.started-at = $started;
    {
      my $*BEHAVE-AUTO-MATCHERS = $auto ?? @captured-matchers !! Array;
      my $*BEHAVE-AGGREGATION-LABEL = $auto-agg-on ?? ($auto-agg-label // Str) !! Str;
      try {
        $example.execute;
        CATCH {
          default {
            if $auto-agg-on {
              my $msg = "exception in {self.full-description($example)}: " ~ .message;
              Failures.list.push(Failure.new(
                :file($example.file.Str),
                :line($example.line),
                :message($msg),
                :aggregation-label($auto-agg-label // Str),
              ));
            } else {
              $error = $_;
            }
          }
        }
      }
    }
    my $finished = now;
    $example.finished-at = $finished;
    $example.duration = ($finished - $started).Real;

    @!timed-examples.push: %(
      example     => $example,
      description => self.full-description($example),
      duration    => $example.duration,
    );

    if $auto {
      my $derived = self.derive-auto-description(@captured-matchers);
      $description = $derived if $derived.defined;
      $!formatter.example-auto-description($example, :$description);
    }

    if $error.defined {
      my %failure-info = (
        description => self.full-description($example),
        file        => $example.file,
        line        => $example.line,
        exception   => $error,
      );
      $!result.add-fail(%failure-info);
      $!formatter.example-fail($example, :failure-info(%failure-info));
      self.maybe-print-slow($example);
      return;
    }

    my $new-failures = Failures.list.elems - $initial-failure-count;

    if $new-failures > 0 {
      my %failure-info = (
        description => self.full-description($example),
        file        => $example.file,
        line        => $example.line,
      );
      $!result.add-fail(%failure-info);
      $!formatter.example-fail($example, :failure-info(%failure-info));
    } else {
      $!result.add-pass;
      $!formatter.example-pass($example);
    }

    self.maybe-print-slow($example);
  }

  method maybe-print-slow(Example $example) {
    return unless $!slow-threshold > 0;
    return unless $example.duration.defined;
    return unless $example.duration >= $!slow-threshold;
    $!formatter.example-slow($example, :threshold($!slow-threshold));
  }

  method maybe-print-memory-leak(Example $example) {
    return unless $!memory-threshold > 0;
    return unless $example.memory-delta.defined;
    return unless $example.memory-delta >= $!memory-threshold;
    $!formatter.example-memory-leak($example, :threshold($!memory-threshold));
  }

  method derive-auto-description(@captured) {
    return Nil unless @captured.elems;
    my %first = @captured[0];
    my $matcher = %first<matcher>;
    my $negated = ?%first<negated>;
    my $desc = $matcher.description;
    return Nil unless $desc.defined && $desc.chars;
    my $verb = $negated ?? 'should not' !! 'should';
    "{$verb} {$desc}";
  }

  method ancestor-groups($node) {
    $node.ancestry.grep(ExampleGroup).List;
  }

  method run-hooks(ExampleGroup $group, Str $phase) {
    my @hooks = $group.hooks($phase);
    return unless @hooks.elems;
    my @runnable;
    my $runnable-collected = False;
    for @hooks -> $hook {
      if $hook.has-filter {
        unless $runnable-collected {
          @runnable = self.runnable-examples($group);
          $runnable-collected = True;
        }
        next unless @runnable.first({ $hook.matches($_) }).defined;
      }
      try {
        ($hook.callback)();
        CATCH {
          default {
            warn "Hook $phase failed in {$group.description}: {$_.message}";
          }
        }
      }
    }
  }

  method run-each-hooks(ExampleGroup $group, Str $phase, Example $example) {
    for $group.hooks($phase) -> $hook {
      next unless $hook.matches($example);
      try {
        ($hook.callback)();
        CATCH {
          default {
            warn "Hook $phase failed in {$group.description}: {$_.message}";
          }
        }
      }
    }
  }

  method runnable-examples(ExampleGroup $group --> List) {
    my @examples;
    for $group.children -> $child {
      given $child {
        when Example {
          @examples.push($child)
            if self.example-matches($child) && !$child.effective-skipped;
        }
        when ExampleGroup {
          @examples.append: self.runnable-examples($child);
        }
      }
    }
    @examples.List;
  }

  method full-description(Example $example) {
    my @parts = @!description-stack.clone;
    @parts.push($example.description);
    @parts.join(' ');
  }

  method print-summary {
    $!formatter.run-summary(
      $!result,
      :$!aborted, :$!fail-fast, :$!order, :$!seed,
    );

    $!formatter.profile-summary(@!timed-examples, :limit($!profile-limit))
      if $!profile-limit > 0;
    $!formatter.memory-profile-summary(@!memory-records, :limit($!memory-profile-limit))
      if $!memory-profile-limit > 0;
    $!formatter.benchmark-summary-section(
      @!benchmark-summaries, @!benchmark-regressions,
      :threshold($!benchmark-threshold),
      :format($!benchmark-format),
      :output($!benchmark-output),
      :runner(self),
    ) if $!benchmark-mode && !$!benchmark-quiet;
  }

  method print-benchmark-summary(
    @summaries       = @!benchmark-summaries,
    @regressions     = @!benchmark-regressions,
    Real :$threshold = $!benchmark-threshold,
    Str  :$format    = $!benchmark-format,
    IO::Path :$output = $!benchmark-output,
  ) {
    $!formatter.benchmark-summary-section(
      @summaries, @regressions,
      :$threshold, :$format, :$output, :runner(self),
    );
  }

  method render-benchmark-output(
    @summaries, @regressions,
    Real :$threshold = $!benchmark-threshold,
    Str  :$format    = $!benchmark-format,
    --> Str
  ) {
    given $format {
      when 'json' {
        BDD::Behave::Benchmark::Format::to-json-document(
          @summaries, @regressions, $threshold,
        );
      }
      default {
        self.render-benchmark-text(@summaries, @regressions, :$threshold);
      }
    }
  }

  method render-benchmark-text(
    @summaries, @regressions,
    Real :$threshold = $!benchmark-threshold,
    --> Str
  ) {
    my @blocks;
    @blocks.push: self.render-bench-summary-table(@summaries);
    if @regressions.elems {
      @blocks.push: '';
      @blocks.push: self.render-bench-comparison-table(@regressions, :$threshold);
    }
    @blocks.join("\n");
  }

  method render-bench-summary-table(@summaries --> Str) {
    my $count   = @summaries.elems;
    my $heading = "Benchmarks ($count measurement" ~ ($count == 1 ?? '' !! 's') ~ '):';

    my @headers = <DESCRIPTION KEY ITER MIN(s) MAX(s) MEAN(s) MEDIAN(s)>;
    my @aligns  = <left left right right right right right>;
    my @rows;
    for @summaries -> %s {
      @rows.push: [
        %s<description>,
        %s<key>,
        %s<iterations>.Str,
        sprintf('%.6f', %s<min>),
        sprintf('%.6f', %s<max>),
        sprintf('%.6f', %s<mean>),
        sprintf('%.6f', %s<median>),
      ];
    }
    my @widths = BDD::Behave::Benchmark::Format::column-widths(@headers, @rows);
    $heading ~ "\n" ~
      BDD::Behave::Benchmark::Format::render-table(@headers, @rows, @widths, @aligns);
  }

  method render-bench-comparison-table(@regressions, Real :$threshold = $!benchmark-threshold --> Str) {
    my @hits          = @regressions.grep(*<regression>);
    my $threshold-pct = sprintf '%.1f%%', $threshold * 100;
    my $heading       = @hits.elems
      ?? red("Benchmark regressions ({@hits.elems}, threshold $threshold-pct):")
      !! "Benchmark comparison (no regressions; threshold $threshold-pct):";

    my @headers = <DESCRIPTION KEY BASELINE CURRENT DELTA>;
    my @aligns  = <left left right right left>;
    my @rows;
    for @regressions -> %r {
      @rows.push: [
        %r<description>,
        %r<key>,
        sprintf('%.6fs', %r<baseline-median>),
        sprintf('%.6fs', %r<median>),
        self.render-delta-cell(%r),
      ];
    }
    my @widths = BDD::Behave::Benchmark::Format::column-widths(@headers, @rows);
    $heading ~ "\n" ~
      BDD::Behave::Benchmark::Format::render-table(@headers, @rows, @widths, @aligns);
  }

  method render-delta-cell(%r --> Str) {
    my $delta-pct = %r<delta-pct>;
    my $sign      = $delta-pct >= 0 ?? '+' !! '';
    my $body      = sprintf '%s%.1f%%', $sign, $delta-pct * 100;
    my ($arrow, $colored);
    if %r<regression> {
      $arrow   = '↑';
      $colored = red("$arrow $body REGRESSION");
    } elsif $delta-pct < -$!benchmark-threshold {
      $arrow   = '↓';
      $colored = green("$arrow $body");
    } elsif $delta-pct > 0 {
      $arrow   = '↑';
      $colored = "$arrow $body";
    } elsif $delta-pct < 0 {
      $arrow   = '↓';
      $colored = "$arrow $body";
    } else {
      $arrow   = '→';
      $colored = "$arrow $body";
    }
    $colored;
  }

  method print-profile(Int $limit = $!profile-limit, @records = @!timed-examples) {
    $!formatter.profile-summary(@records, :$limit);
  }

  method print-memory-profile(Int $limit = $!memory-profile-limit,
                              @records = @!memory-records) {
    $!formatter.memory-profile-summary(@records, :$limit);
  }
}
