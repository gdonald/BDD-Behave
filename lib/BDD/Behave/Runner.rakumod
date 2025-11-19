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

  method success {
    $!failed == 0;
  }
}

our class Runner {
  has Int $!indent = 0;
  has @!description-stack;
  has RunResult $.result .= new;

  method run(Suite $suite) {
    self.run-suite($suite);
    self.print-summary;
    $!result;
  }

  method run-suite(Suite $suite) {
    # A suite is a top-level container for a file
    # Walk all its children (groups and examples)
    for $suite.children -> $child {
      given $child {
        when ExampleGroup { self.run-group($child) }
        when Example { self.run-example($child) }
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

    # Run before-all hooks
    self.run-hooks($group, 'before-all');

    # Process all children
    for $group.children -> $child {
      given $child {
        when ExampleGroup { self.run-group($child) }
        when Example {
          # Run with before-each/after-each hooks
          self.run-hooks($group, 'before-each');
          self.run-example($child);
          self.run-hooks($group, 'after-each');
        }
      }
    }

    # Run after-all hooks
    self.run-hooks($group, 'after-all');

    # Restore context
    $!indent--;
    @!description-stack.pop;
  }

  method run-example(Example $example) {
    my $description = $example.description;

    if $example.pending {
      self.print-indent;
      say light-blue("⮑  '{$description}'");
      self.print-indent;
      say light-blue("    ⮑  PENDING");
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
          say red("    ⮑  FAILURE");
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
      say red("    ⮑  FAILURE");
    } else {
      # Example passed
      $!result.add-pass;
      self.print-indent;
      say green("    ⮑  SUCCESS");
    }
  }

  method run-hooks(ExampleGroup $group, Str $phase) {
    for $group.hooks($phase) -> $hook {
      try {
        $hook();
        CATCH {
          default {
            warn "Hook $phase failed in {$group.description}: {$_.message}";
          }
        }
      }
    }
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
    my $passed-msg = $!result.passed > 0 ?? green("{$!result.passed} passed") !! '';

    my @parts = ($total-msg, $failed-msg, $pending-msg, $passed-msg).grep(*.so);
    say @parts.join(', ');
  }
}
