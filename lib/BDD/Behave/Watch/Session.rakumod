unit module BDD::Behave::Watch::Session;

use BDD::Behave::Watch::Watcher;
use BDD::Behave::Watch::SmartSelector;
use BDD::Behave::Watch::UI;

our class RunRequest {
  has IO::Path @.specs;
  has Str      $.reason is required;
  has Bool     $.only-failures = False;
}

our class Session {
  has BDD::Behave::Watch::Watcher::Watcher              $.watcher       is required;
  has BDD::Behave::Watch::SmartSelector::Selector       $.selector      is required;
  has BDD::Behave::Watch::UI::UI                        $.ui            is required;
  has @.all-specs;
  has &.runner       is required;
  has &.sleep-fn     = -> $secs { sleep $secs };
  has Real $.poll-interval = 0.25;
  has Bool $.running-test-after-initialize = True;
  has Int  $.max-iterations = -1;
  has Bool $!stop = False;
  has @!last-selection;

  method run() {
    $!stop = False;
    $.watcher.initialize;
    $.ui.start-reader;

    self!print-startup;

    if $.running-test-after-initialize {
      self!execute(RunRequest.new(
        :specs($.all-specs.map(*.IO)),
        :reason('initial run'),
      ));
    }

    my $iter = 0;
    until $!stop {
      last if $.max-iterations >= 0 && $iter >= $.max-iterations;
      $iter++;

      (&!sleep-fn)($.poll-interval);

      my $cmd = $.ui.poll-command;
      with $cmd {
        my $req = self!command-to-request($cmd);
        if $req.defined {
          self!execute($req);
        }
        next;
      }

      my @changes = $.watcher.poll.list;
      next unless @changes.elems;

      $.ui.change-summary(@changes);
      my @selected = $.selector.select-specs(@changes, $.all-specs).list;

      if !@selected.elems {
        $.ui.info("no specs mapped to these changes; skipping");
        next;
      }

      self!execute(RunRequest.new(
        :specs(@selected.map(*.IO)),
        :reason('change detected'),
      ));
    }

    $.ui.stop;
  }

  method stopped(--> Bool) { $!stop }

  method !command-to-request(Str $cmd) {
    given $cmd {
      when 'q' | 'quit' | 'exit' {
        $.ui.info('quitting watch');
        $!stop = True;
        return Nil;
      }
      when 'r' | 'rerun' | '' {
        my @specs = @!last-selection.elems ?? @!last-selection !! $.all-specs.map(*.IO);
        return RunRequest.new(
          :@specs,
          :reason('manual rerun'),
        );
      }
      when 'a' | 'all' {
        return RunRequest.new(
          :specs($.all-specs.map(*.IO)),
          :reason('rerun all'),
        );
      }
      when 'f' | 'failed' {
        return RunRequest.new(
          :specs($.all-specs.map(*.IO)),
          :reason('rerun failed only'),
          :only-failures,
        );
      }
      when 'h' | '?' | 'help' {
        $.ui.prompt;
        return Nil;
      }
      default {
        $.ui.warn("unknown command: '$cmd'");
        $.ui.prompt;
        return Nil;
      }
    }
  }

  method !execute(RunRequest $req) {
    $.ui.run-banner($req.specs, $req.reason);
    @!last-selection = $req.specs.list;
    my $exit = (&!runner)($req);
    $.ui.run-finished($exit == 0);
    $.ui.prompt;
  }

  method !print-startup() {
    $.ui.banner('starting watch mode');
    my $tracked = $.watcher.tracked-count;
    $.ui.info("tracking $tracked files");
  }
}
