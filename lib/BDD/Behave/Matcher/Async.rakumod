unit module BDD::Behave::Matcher::Async;

use BDD::Behave::Matcher;

constant DEFAULT-PROMISE-TIMEOUT = 5;

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
