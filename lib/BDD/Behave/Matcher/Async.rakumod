unit module BDD::Behave::Matcher::Async;

use BDD::Behave::Matcher;

constant DEFAULT-PROMISE-TIMEOUT     = 5;
constant DEFAULT-STREAM-WINDOW       = 1;
constant DEFAULT-EVENTUALLY-TIMEOUT  = 2;
constant DEFAULT-EVENTUALLY-INTERVAL = 0.05;

sub bounded-wait(Promise:D $promise, Real:D $timeout --> Nil) {
  if $promise.status === Planned {
    await Promise.anyof($promise, Promise.in($timeout));
  }
}

sub capture-cause(Promise:D $promise --> Mu) {
  my $cause;
  try {
    $promise.result;
    CATCH { default { $cause = $_; } }
  }
  $cause;
}

sub is-stream-source($actual --> Bool) {
  ?($actual ~~ Supply) || ?($actual ~~ Channel);
}

sub collect-emissions($source, Real:D $window, Int :$max-count) {
  my @collected;
  my Bool $completed  = False;
  my      $quit-cause;

  react {
    whenever Promise.in($window) {
      done;
    }
    whenever $source -> $value {
      @collected.push($value);
      done if $max-count.defined && @collected.elems >= $max-count;
      LAST {
        $completed = True;
        done;
      }
      QUIT {
        $quit-cause = $_;
        done;
      }
    }
  }

  (@collected, $completed, $quit-cause);
}

class BeKeptMatcher does Matcher is export {
  has Real $.timeout = DEFAULT-PROMISE-TIMEOUT;
  has Bool $.promise-given is rw = True;
  has Bool $.timed-out     is rw = False;
  has Mu   $.value         is rw;
  has Mu   $.cause         is rw;

  method !reset(--> Nil) {
    $!promise-given = True;
    $!timed-out     = False;
    $!value         = Nil;
    $!cause         = Nil;
  }

  method matches($actual --> Bool) {
    self!reset;
    $!promise-given = ?($actual ~~ Promise);
    return False unless $!promise-given;

    bounded-wait($actual, $!timeout);

    given $actual.status {
      when Kept    { $!value = $actual.result; True }
      when Broken  { $!cause = capture-cause($actual); False }
      default      { $!timed-out = True; False }
    }
  }

  method !cause-detail(--> Str) {
    "{$!cause.^name}: {$!cause.message}";
  }

  method failure-message($actual --> Str) {
    unless $!promise-given {
      return "expected a Promise for be-kept, but got " ~ $actual.raku;
    }
    if $!timed-out {
      "expected Promise to be kept within {$!timeout}s, but it was still pending";
    } elsif $!cause.defined {
      "expected Promise to be kept, but it was broken ({self!cause-detail})";
    } else {
      "expected Promise to be kept";
    }
  }

  method failure-message-negated($actual --> Str) {
    "expected Promise not to be kept";
  }

  method description(--> Str) { "be kept" }
}

class BeBrokenMatcher does Matcher is export {
  has Real $.timeout = DEFAULT-PROMISE-TIMEOUT;
  has Bool $.promise-given is rw = True;
  has Bool $.timed-out     is rw = False;
  has Bool $.was-kept      is rw = False;
  has Mu   $.value         is rw;
  has Mu   $.cause         is rw;

  method !reset(--> Nil) {
    $!promise-given = True;
    $!timed-out     = False;
    $!was-kept      = False;
    $!value         = Nil;
    $!cause         = Nil;
  }

  method matches($actual --> Bool) {
    self!reset;
    $!promise-given = ?($actual ~~ Promise);
    return False unless $!promise-given;

    bounded-wait($actual, $!timeout);

    given $actual.status {
      when Broken  { $!cause = capture-cause($actual); True }
      when Kept    { $!was-kept = True; $!value = $actual.result; False }
      default      { $!timed-out = True; False }
    }
  }

  method !cause-detail(--> Str) {
    "{$!cause.^name}: {$!cause.message}";
  }

  method failure-message($actual --> Str) {
    unless $!promise-given {
      return "expected a Promise for be-broken, but got " ~ $actual.raku;
    }
    if $!timed-out {
      "expected Promise to be broken within {$!timeout}s, but it was still pending";
    } elsif $!was-kept {
      "expected Promise to be broken, but it was kept with " ~ $!value.raku;
    } else {
      "expected Promise to be broken";
    }
  }

  method failure-message-negated($actual --> Str) {
    if $!cause.defined {
      "expected Promise not to be broken, but it was ({self!cause-detail})";
    } else {
      "expected Promise not to be broken";
    }
  }

  method description(--> Str) { "be broken" }
}

class CompleteWithinMatcher does Matcher is export {
  has Real $.duration is required;
  has Bool $.promise-given is rw = True;
  has Bool $.timed-out     is rw = False;
  has Mu   $.final-status  is rw;
  has Mu   $.value         is rw;
  has Mu   $.cause         is rw;

  method !reset(--> Nil) {
    $!promise-given = True;
    $!timed-out     = False;
    $!final-status  = Nil;
    $!value         = Nil;
    $!cause         = Nil;
  }

  method matches($actual --> Bool) {
    self!reset;
    $!promise-given = ?($actual ~~ Promise);
    return False unless $!promise-given;

    bounded-wait($actual, $!duration);

    $!final-status = $actual.status;
    given $actual.status {
      when Kept   { $!value = $actual.result; True }
      when Broken { $!cause = capture-cause($actual); True }
      default     { $!timed-out = True; False }
    }
  }

  method !cause-detail(--> Str) {
    "{$!cause.^name}: {$!cause.message}";
  }

  method failure-message($actual --> Str) {
    unless $!promise-given {
      return "expected a Promise for complete-within, but got " ~ $actual.raku;
    }
    "expected Promise to complete within {$!duration}s, but it was still pending";
  }

  method failure-message-negated($actual --> Str) {
    if $!final-status === Kept {
      "expected Promise not to complete within {$!duration}s, but it was kept with " ~ $!value.raku;
    } elsif $!final-status === Broken {
      "expected Promise not to complete within {$!duration}s, but it was broken ({self!cause-detail})";
    } else {
      "expected Promise not to complete within {$!duration}s";
    }
  }

  method description(--> Str) { "complete within {$!duration}s" }

  method expected-value(--> Mu) { $!duration }
}

class EmitMatcher does Matcher is export {
  has @.expected;
  has Real $.window = DEFAULT-STREAM-WINDOW;
  has Bool $.source-given is rw = True;
  has      @.collected    is rw;
  has Bool $.completed    is rw = False;
  has Mu   $.quit-cause   is rw;

  method !reset(--> Nil) {
    $!source-given = True;
    @!collected    = ();
    $!completed    = False;
    $!quit-cause   = Nil;
  }

  method matches($actual --> Bool) {
    self!reset;
    $!source-given = is-stream-source($actual);
    return False unless $!source-given;

    my ($vals, $done, $cause) = collect-emissions(
      $actual, $!window, :max-count(@!expected.elems),
    );
    @!collected  = $vals.list;
    $!completed  = $done;
    $!quit-cause = $cause;

    return False if @!collected.elems != @!expected.elems;
    for ^@!expected.elems -> $i {
      return False unless @!collected[$i] eqv @!expected[$i];
    }
    True;
  }

  method failure-message($actual --> Str) {
    unless $!source-given {
      return "expected a Supply or Channel for emit, but got " ~ $actual.raku;
    }
    if $!quit-cause.defined {
      return "expected stream to emit " ~ @!expected.raku
           ~ ", but it quit ({$!quit-cause.^name}: {$!quit-cause.message})";
    }
    "expected stream to emit " ~ @!expected.raku
      ~ " within {$!window}s, but it emitted " ~ @!collected.raku;
  }

  method failure-message-negated($actual --> Str) {
    "expected stream not to emit " ~ @!expected.raku;
  }

  method description(--> Str) { "emit " ~ @!expected.raku }

  method expected-value(--> Mu) { @!expected.list }
}

class EmitAtLeastMatcher does Matcher is export {
  has Int  $.minimum is required;
  has Real $.window = DEFAULT-STREAM-WINDOW;
  has Bool $.source-given is rw = True;
  has      @.collected    is rw;
  has Bool $.completed    is rw = False;
  has Mu   $.quit-cause   is rw;

  method !reset(--> Nil) {
    $!source-given = True;
    @!collected    = ();
    $!completed    = False;
    $!quit-cause   = Nil;
  }

  method !count-phrase(--> Str) {
    "{$!minimum} value" ~ ($!minimum == 1 ?? '' !! 's');
  }

  method matches($actual --> Bool) {
    self!reset;
    $!source-given = is-stream-source($actual);
    return False unless $!source-given;

    my ($vals, $done, $cause) = collect-emissions(
      $actual, $!window, :max-count($!minimum),
    );
    @!collected  = $vals.list;
    $!completed  = $done;
    $!quit-cause = $cause;

    @!collected.elems >= $!minimum;
  }

  method failure-message($actual --> Str) {
    unless $!source-given {
      return "expected a Supply or Channel for emit-at-least, but got "
           ~ $actual.raku;
    }
    if $!quit-cause.defined {
      return "expected stream to emit at least {self!count-phrase}"
           ~ ", but it quit ({$!quit-cause.^name}: {$!quit-cause.message})"
           ~ " after {@!collected.elems}";
    }
    "expected stream to emit at least {self!count-phrase} within {$!window}s"
      ~ ", but it emitted {@!collected.elems}";
  }

  method failure-message-negated($actual --> Str) {
    "expected stream not to emit at least {self!count-phrase}";
  }

  method description(--> Str) { "emit at least {self!count-phrase}" }

  method expected-value(--> Mu) { $!minimum }
}

class CompleteMatcher does Matcher is export {
  has Real $.window = DEFAULT-STREAM-WINDOW;
  has Bool $.source-given is rw = True;
  has      @.collected    is rw;
  has Bool $.completed    is rw = False;
  has Mu   $.quit-cause   is rw;

  method !reset(--> Nil) {
    $!source-given = True;
    @!collected    = ();
    $!completed    = False;
    $!quit-cause   = Nil;
  }

  method matches($actual --> Bool) {
    self!reset;
    $!source-given = is-stream-source($actual);
    return False unless $!source-given;

    my ($vals, $done, $cause) = collect-emissions($actual, $!window);
    @!collected  = $vals.list;
    $!completed  = $done;
    $!quit-cause = $cause;

    $!completed;
  }

  method !emit-phrase(--> Str) {
    "emitted {@!collected.elems} value" ~ (@!collected.elems == 1 ?? '' !! 's');
  }

  method failure-message($actual --> Str) {
    unless $!source-given {
      return "expected a Supply or Channel for complete, but got "
           ~ $actual.raku;
    }
    if $!quit-cause.defined {
      return "expected stream to complete within {$!window}s, but it quit"
           ~ " ({$!quit-cause.^name}: {$!quit-cause.message})";
    }
    "expected stream to complete within {$!window}s, but it was still active"
      ~ " ({self!emit-phrase})";
  }

  method failure-message-negated($actual --> Str) {
    "expected stream not to complete within {$!window}s";
  }

  method description(--> Str) { "complete within {$!window}s" }

  method expected-value(--> Mu) { $!window }
}

class EventuallyMatcher does Matcher is export {
  has Matcher $.inner is required;
  has Real $.timeout  = DEFAULT-EVENTUALLY-TIMEOUT;
  has Real $.interval = DEFAULT-EVENTUALLY-INTERVAL;
  has Bool $.callable-given is rw = True;
  has Mu   $.last-actual    is rw;
  has Mu   $.last-exception is rw;
  has Int  $.iterations     is rw = 0;
  has Real $.elapsed        is rw = 0;

  method !reset(--> Nil) {
    $!callable-given = True;
    $!last-actual    = Nil;
    $!last-exception = Nil;
    $!iterations     = 0;
    $!elapsed        = 0;
  }

  method matches($actual --> Bool) {
    self!reset;
    $!callable-given = ?($actual ~~ Callable);
    return False unless $!callable-given;

    my $start    = now;
    my $deadline = $start + $!timeout;

    loop {
      $!iterations++;
      $!last-exception = Nil;
      my $value;
      my $caught = False;
      try {
        $value = $actual.();
        CATCH { default { $!last-exception = $_; $caught = True; } }
      }
      unless $caught {
        $!last-actual = $value;
        if ?$!inner.matches($value) {
          $!elapsed = now - $start;
          return True;
        }
      }
      if now >= $deadline {
        $!elapsed = now - $start;
        return False;
      }
      sleep $!interval if $!interval > 0;
    }
  }

  method !timing-suffix(--> Str) {
    my $plural = $!iterations == 1 ?? '' !! 's';
    "after {$!iterations} iteration{$plural} in {$!elapsed.fmt('%.2f')}s";
  }

  method !inner-failure(--> Str) {
    my $msg = $!inner.failure-message($!last-actual);
    return $msg if $msg.defined;
    "did not match {$!inner.description}";
  }

  method failure-message($actual --> Str) {
    unless $!callable-given {
      return "expected a Callable for eventually, but got " ~ $actual.raku;
    }
    if $!last-exception.defined {
      return "eventually: block threw {$!last-exception.^name}: "
           ~ "{$!last-exception.message} ({self!timing-suffix})";
    }
    "eventually: {self!inner-failure} ({self!timing-suffix})";
  }

  method failure-message-negated($actual --> Str) {
    unless $!callable-given {
      return "expected a Callable for eventually, but got " ~ $actual.raku;
    }
    "eventually: expected block not to {$!inner.description}, "
      ~ "but it matched (after {$!iterations} iteration"
      ~ ($!iterations == 1 ?? '' !! 's') ~ ")";
  }

  method description(--> Str) {
    "eventually {$!inner.description}";
  }

  method expected-value(--> Mu) { $!inner.expected-value }
}
