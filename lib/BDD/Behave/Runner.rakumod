unit module BDD::Behave::Runner;

use BDD::Behave::Colors;
use BDD::Behave::Failures;
use BDD::Behave::SpecTree;

constant Suite = BDD::Behave::SpecTree::Suite;
constant ExampleGroup = BDD::Behave::SpecTree::ExampleGroup;
constant Example = BDD::Behave::SpecTree::Example;

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
  has Bool $!focus-mode = False;

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
    for $suite.children -> $child {
      given $child {
        when ExampleGroup { self.run-group($child) if self.group-matches($child) }
        when Example      { self.handle-example($child) if self.example-matches($child) }
      }
    }
  }

  method run-group(ExampleGroup $group) {
    # Print the group description with arrow
    self.print-indent;
    say "⮑  '{$group.description}'";

    # Track description for nested context
    @!description-stack.push($group.description);
    $!indent++;

    my $group-skipped = $group.effective-skipped;

    # Skipped groups don't run before-all / after-all
    self.run-hooks($group, 'before-all') unless $group-skipped;

    # Process all children
    for $group.children -> $child {
      given $child {
        when ExampleGroup { self.run-group($child) if self.group-matches($child) }
        when Example      { self.handle-example($child) if self.example-matches($child) }
      }
    }

    self.run-hooks($group, 'after-all') unless $group-skipped;

    # Restore context
    $!indent--;
    @!description-stack.pop;
  }

  method handle-example(Example $example) {
    if $example.effective-skipped {
      self.print-skipped($example);
      return;
    }

    # before-each runs outer-to-inner across the ancestor chain
    for self.ancestor-groups($example) -> $ancestor {
      self.run-each-hooks($ancestor, 'before-each', $example);
    }

    self.run-example($example);

    # after-each runs inner-to-outer
    for self.ancestor-groups($example).reverse -> $ancestor {
      self.run-each-hooks($ancestor, 'after-each', $example);
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

    return True unless @!include-tags.elems;
    @tags.first({ $_ ∈ @!include-tags }).defined;
  }

  method group-matches(ExampleGroup $group --> Bool) {
    return True unless @!include-tags.elems || @!exclude-tags.elems || $!focus-mode;

    for $group.children -> $child {
      given $child {
        when Example       { return True if self.example-matches($child) }
        when ExampleGroup  { return True if self.group-matches($child)   }
      }
    }
    False;
  }

  method run-example(Example $example) {
    my $description = $example.description;

    if $example.pending {
      self.print-indent;
      say light-blue("⮑  '{$description}'");
      self.print-indent;
      say light-blue("  ⮑  PENDING");
      $!result.add-pending;
      return;
    }

    my $initial-failure-count = Failures.list.elems;

    # Print the example description
    self.print-indent;
    say "⮑  '{$description}'";

    try {
      $example.execute;
      CATCH {
        default {
          # Capture the exception
          my $error = %(
            description => self.full-description($example),
            file => $example.file,
            line => $example.line,
            exception => $_,
          );
          $!result.add-fail($error);
          self.print-indent;
          say red("  ⮑  FAILURE");
          return;
        }
      }
    }

    # Check if any failures were recorded during execution
    my $new-failures = Failures.list.elems - $initial-failure-count;

    if $new-failures > 0 {
      # Example failed via expect
      $!result.add-fail(%(
          description => self.full-description($example),
          file => $example.file,
          line => $example.line,
      ));
      self.print-indent;
      say red("  ⮑  FAILURE");
    } else {
      # Example passed
      $!result.add-pass;
      self.print-indent;
      say green("  ⮑  SUCCESS");
    }
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
  }
}
