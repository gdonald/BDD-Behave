unit module BDD::Behave::Matcher::Boolean;

use BDD::Behave::Matcher;

class BeTruthyMatcher does Matcher is export {
  method matches($actual --> Bool) {
    ?$actual;
  }

  method failure-message($actual --> Str) {
    "expected " ~ $actual.raku ~ " to be truthy";
  }

  method failure-message-negated($actual --> Str) {
    "expected " ~ $actual.raku ~ " not to be truthy";
  }

  method description(--> Str) { 'be truthy' }
}

class BeFalsyMatcher does Matcher is export {
  method matches($actual --> Bool) {
    !$actual;
  }

  method failure-message($actual --> Str) {
    "expected " ~ $actual.raku ~ " to be falsy";
  }

  method failure-message-negated($actual --> Str) {
    "expected " ~ $actual.raku ~ " not to be falsy";
  }

  method description(--> Str) { 'be falsy' }
}

class BeNilMatcher does Matcher is export {
  method matches($actual --> Bool) {
    !$actual.defined;
  }

  method failure-message($actual --> Str) {
    "expected " ~ $actual.raku ~ " to be nil";
  }

  method failure-message-negated($actual --> Str) {
    "expected " ~ $actual.raku ~ " not to be nil";
  }

  method description(--> Str) { 'be nil' }
}
