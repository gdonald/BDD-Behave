unit module BDD::Behave::Matcher::Numeric;

use BDD::Behave::Matcher;

class BeGreaterThanMatcher does Matcher is export {
  has $.expected;

  method matches($actual --> Bool) {
    return False unless $actual.defined;
    return False unless $actual ~~ Real;
    ?($actual > $!expected);
  }

  method failure-message($actual --> Str) {
    "expected " ~ $actual.raku ~ " to be greater than " ~ $!expected.raku;
  }

  method failure-message-negated($actual --> Str) {
    "expected " ~ $actual.raku ~ " not to be greater than " ~ $!expected.raku;
  }

  method expected-value(--> Mu) { $!expected }

  method description(--> Str) { 'be greater than ' ~ $!expected.raku }
}

class BeGreaterThanOrEqualMatcher does Matcher is export {
  has $.expected;

  method matches($actual --> Bool) {
    return False unless $actual.defined;
    return False unless $actual ~~ Real;
    ?($actual >= $!expected);
  }

  method failure-message($actual --> Str) {
    "expected " ~ $actual.raku ~ " to be greater than or equal to "
      ~ $!expected.raku;
  }

  method failure-message-negated($actual --> Str) {
    "expected " ~ $actual.raku ~ " not to be greater than or equal to "
      ~ $!expected.raku;
  }

  method expected-value(--> Mu) { $!expected }

  method description(--> Str) {
    'be greater than or equal to ' ~ $!expected.raku;
  }
}

class BeLessThanMatcher does Matcher is export {
  has $.expected;

  method matches($actual --> Bool) {
    return False unless $actual.defined;
    return False unless $actual ~~ Real;
    ?($actual < $!expected);
  }

  method failure-message($actual --> Str) {
    "expected " ~ $actual.raku ~ " to be less than " ~ $!expected.raku;
  }

  method failure-message-negated($actual --> Str) {
    "expected " ~ $actual.raku ~ " not to be less than " ~ $!expected.raku;
  }

  method expected-value(--> Mu) { $!expected }

  method description(--> Str) { 'be less than ' ~ $!expected.raku }
}

class BeLessThanOrEqualMatcher does Matcher is export {
  has $.expected;

  method matches($actual --> Bool) {
    return False unless $actual.defined;
    return False unless $actual ~~ Real;
    ?($actual <= $!expected);
  }

  method failure-message($actual --> Str) {
    "expected " ~ $actual.raku ~ " to be less than or equal to "
      ~ $!expected.raku;
  }

  method failure-message-negated($actual --> Str) {
    "expected " ~ $actual.raku ~ " not to be less than or equal to "
      ~ $!expected.raku;
  }

  method expected-value(--> Mu) { $!expected }

  method description(--> Str) {
    'be less than or equal to ' ~ $!expected.raku;
  }
}

class BeBetweenMatcher does Matcher is export {
  has $.min;
  has $.max;
  has Bool $.exclusive = False;

  method matches($actual --> Bool) {
    return False unless $actual.defined;
    return False unless $actual ~~ Real;
    if $!exclusive {
      ?($actual > $!min && $actual < $!max);
    } else {
      ?($actual >= $!min && $actual <= $!max);
    }
  }

  method bounds-clause(--> Str) {
    $!exclusive
      ?? $!min.raku ~ ' and ' ~ $!max.raku ~ ' (exclusive)'
      !! $!min.raku ~ ' and ' ~ $!max.raku ~ ' (inclusive)';
  }

  method failure-message($actual --> Str) {
    "expected " ~ $actual.raku ~ " to be between " ~ self.bounds-clause;
  }

  method failure-message-negated($actual --> Str) {
    "expected " ~ $actual.raku ~ " not to be between " ~ self.bounds-clause;
  }

  method expected-value(--> Mu) { [$!min, $!max] }

  method description(--> Str) { 'be between ' ~ self.bounds-clause }
}

class BeWithinMatcher does Matcher is export {
  has $.delta;
  has $.expected;

  method matches($actual --> Bool) {
    return False unless $actual.defined;
    return False unless $actual ~~ Real;
    return False unless $!expected.defined;
    return False unless $!expected ~~ Real;
    ?(abs($actual - $!expected) <= $!delta);
  }

  method failure-message($actual --> Str) {
    "expected " ~ $actual.raku ~ " to be within " ~ $!delta.raku
      ~ " of " ~ $!expected.raku;
  }

  method failure-message-negated($actual --> Str) {
    "expected " ~ $actual.raku ~ " not to be within " ~ $!delta.raku
      ~ " of " ~ $!expected.raku;
  }

  method expected-value(--> Mu) { $!expected }

  method description(--> Str) {
    'be within ' ~ $!delta.raku ~ ' of ' ~ $!expected.raku;
  }
}
