unit module BDD::Behave::Runner;

use BDD::Behave::Colors;
use BDD::Behave::Failure;
use BDD::Behave::Failures;
use BDD::Behave::SpecTree;

need BDD::Behave::Mock::Stub;
need BDD::Behave::LetRuntime;

constant Suite = BDD::Behave::SpecTree::Suite;
constant ExampleGroup = BDD::Behave::SpecTree::ExampleGroup;
constant Example = BDD::Behave::SpecTree::Example;
constant LetRuntime = BDD::Behave::LetRuntime::LetRuntime;

our class RunResult {
  has Int $.total = 0;
  has Int $.passed = 0;
  has Int $.failed = 0;
  has Int $.pending = 0;
  has Int $.skipped = 0;
  has @.errors;

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
  has Int $!indent = 0;
  has @!description-stack;
  has RunResult $.result .= new;
  has @.include-tags;
  has @.exclude-tags;
  has @.example-patterns;
  has $.aggregate-failures = False;
  has Bool $!focus-mode = False;
  has Str $.order = 'defined';
  has Int $.seed;
  has Int $!rng-state;
  has Int $.fail-fast = 0;
  has Bool $.aborted = False;

  submethod TWEAK {
    die "order must be 'random' or 'defined' (got: '$!order')"
      unless $!order eq 'random' | 'defined';

    die "fail-fast must be 0 or a positive integer (got: $!fail-fast)"
      if $!fail-fast < 0;

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
    self.run-suite($suite);
    self.print-summary;
    $!result;
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
    self.print-indent;
    say "⮑  '{$group.description}'";

    @!description-stack.push($group.description);
    $!indent++;

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

    $!indent--;
    @!description-stack.pop;
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

    my @around-hooks = self.matching-around-each-hooks($example);

    my $continuation-called = False;
    my &core = sub {
      $continuation-called = True;
      self.run-each-and-example($example);
    };

    if !@around-hooks.elems {
      core();
      return;
    }

    my &chain = &core;
    for @around-hooks.reverse -> $hook {
      my &next = &chain;
      &chain = sub { ($hook.callback)(&next) };
    }

    try {
      chain();
      CATCH {
        default {
          if $continuation-called {
            warn "around-each hook raised after example: {.message}";
          } else {
            self.print-indent;
            say "⮑  '{$example.description}'";
            $!result.add-fail(%(
              description => self.full-description($example),
              file        => $example.file,
              line        => $example.line,
              exception   => $_,
            ));
            self.print-indent;
            say red("  ⮑  FAILURE");
          }
          return;
        }
      }
    }

    unless $continuation-called {
      self.print-around-skipped($example);
    }
  }

  method run-each-and-example(Example $example) {
    for self.ancestor-groups($example) -> $ancestor {
      self.run-each-hooks($ancestor, 'before-each', $example);
    }

    self.run-example($example);

    for self.ancestor-groups($example).reverse -> $ancestor {
      self.run-each-hooks($ancestor, 'after-each', $example);
    }
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
    self.print-indent;
    say light-blue("⮑  '{$example.description}'");
    self.print-indent;
    say light-blue("  ⮑  SKIPPED (around-each did not invoke continuation)");
    $!result.add-skipped;
  }

  method mark-around-all-skipped(ExampleGroup $group) {
    self.print-indent;
    say light-blue("⮑  SKIPPED (around-all did not invoke continuation)");
    for self.runnable-examples($group) -> $example {
      next if $example.effective-skipped;
      $!result.add-skipped;
    }
  }

  method print-skipped(Example $example) {
    self.print-indent;
    say light-blue("⮑  '{$example.description}'");
    self.print-indent;
    say light-blue("  ⮑  SKIPPED");
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

    True;
  }

  method group-matches(ExampleGroup $group --> Bool) {
    return True unless @!include-tags.elems
                    || @!exclude-tags.elems
                    || @!example-patterns.elems
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
      self.print-indent;
      say light-blue("⮑  '{$description}'");
      self.print-indent;
      say light-blue("  ⮑  PENDING");
      $!result.add-pending;
      return;
    }

    my ($auto-agg-on, $auto-agg-label) = self.resolve-auto-aggregation($example);

    my $initial-failure-count = Failures.list.elems;

    if !$auto {
      self.print-indent;
      say "⮑  '{$description}'";
    }

    my @captured-matchers;
    my $error;
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

    if $auto {
      my $derived = self.derive-auto-description(@captured-matchers);
      $description = $derived if $derived.defined;
      self.print-indent;
      say "⮑  '{$description}'";
    }

    if $error.defined {
      $!result.add-fail(%(
        description => self.full-description($example),
        file => $example.file,
        line => $example.line,
        exception => $error,
      ));
      self.print-indent;
      say red("  ⮑  FAILURE");
      return;
    }

    my $new-failures = Failures.list.elems - $initial-failure-count;

    if $new-failures > 0 {
      $!result.add-fail(%(
          description => self.full-description($example),
          file => $example.file,
          line => $example.line,
      ));
      self.print-indent;
      say red("  ⮑  FAILURE");
    } else {
      $!result.add-pass;
      self.print-indent;
      say green("  ⮑  SUCCESS");
    }
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

  method print-indent {
    print '  ' x $!indent;
  }

  method print-summary {
    say '';

    # Print failures if any
    Failures.say;

    # Print counts
    my $total-msg = "{$!result.total} example" ~ ($!result.total == 1 ?? '' !! 's');
    my $failed-msg = $!result.failed > 0 ?? red("{$!result.failed} failed") !! '';
    my $pending-msg = $!result.pending > 0 ?? light-blue("{$!result.pending} pending") !! '';
    my $skipped-msg = $!result.skipped > 0 ?? light-blue("{$!result.skipped} skipped") !! '';
    my $passed-msg = $!result.passed > 0 ?? green("{$!result.passed} passed") !! '';

    my @parts = ($total-msg, $failed-msg, $pending-msg, $skipped-msg, $passed-msg).grep(*.so);
    say @parts.join(', ');

    if $!aborted {
      my $word = $!fail-fast == 1 ?? 'failure' !! 'failures';
      say red("Aborted after $!fail-fast $word (--fail-fast)");
    }

    if $!order eq 'random' && $!seed.defined {
      say "Randomized with seed $!seed";
    }
  }
}
