unit module BDD::Behave::Matcher::Exception;

use BDD::Behave::Matcher;
use BDD::Behave::TypeName;

class RaiseErrorMatcher does Matcher is export {
  has Mu $.expected-type;
  has Bool $.has-type = False;
  has $.expected-message;
  has $.raised-exception is rw;
  has Bool $.callable-given is rw = True;
  has Str $.miss-reason is rw;

  method !miss(Str $reason --> Bool) {
    $!miss-reason = $reason;
    False;
  }

  method !message-matches($actual-message --> Bool) {
    given $!expected-message {
      when Regex { ?($actual-message ~~ $_) }
      default    { $actual-message eq $_.Str }
    }
  }

  method check-captured(--> Bool) {
    $!miss-reason = Str;
    return self!miss('non-callable') unless $!callable-given;
    return self!miss('none') unless $!raised-exception.defined;

    if $!has-type && !($!raised-exception ~~ $!expected-type) {
      return self!miss('type');
    }

    if $!expected-message.defined
        && !self!message-matches($!raised-exception.message) {
      return self!miss('message');
    }

    True;
  }

  method matches($actual --> Bool) {
    $!raised-exception = Nil;
    $!callable-given   = ?($actual ~~ Callable);
    return self!miss('non-callable') unless $!callable-given;

    try {
      $actual.();
      CATCH {
        default { $!raised-exception = $_; }
      }
    }
    self.check-captured;
  }

  method !head(--> Str) {
    $!has-type ?? "raise " ~ short-type-name($!expected-type) !! "raise an error";
  }

  method !message-clause(--> Str) {
    given $!expected-message {
      when Regex { " with message matching " ~ $_.raku }
      default    { " with message " ~ $_.Str.raku }
    }
  }

  method description(--> Str) {
    my $d = self!head;
    $!expected-message.defined ?? $d ~ self!message-clause !! $d;
  }

  method !raised-detail(--> Str) {
    "{short-type-name($!raised-exception)}: {$!raised-exception.message}";
  }

  method failure-message($actual --> Str) {
    unless $!callable-given {
      return "expected a Callable for raise-error, but got " ~ $actual.raku;
    }
    given $!miss-reason {
      when 'none' {
        "expected block to " ~ self.description ~ ", but none was raised";
      }
      when 'type' | 'message' {
        "expected block to " ~ self.description
          ~ ", but raised " ~ self!raised-detail;
      }
      default {
        "expected block to " ~ self.description;
      }
    }
  }

  method failure-message-negated($actual --> Str) {
    my $head = "expected block not to " ~ self.description;
    if $!raised-exception.defined {
      $head ~ ", but one was raised (" ~ self!raised-detail ~ ")";
    } else {
      $head ~ ", but one was raised";
    }
  }

  method expected-value(--> Mu) {
    if $!has-type {
      $!expected-type;
    } elsif $!expected-message.defined {
      $!expected-message;
    } else {
      Nil;
    }
  }
}
