unit module BDD::Behave::Matcher;

role Matcher is export {
  method matches($actual --> Bool) { ... }
  method failure-message($actual --> Str) { Str }
  method failure-message-negated($actual --> Str) { Str }
  method expected-value(--> Mu) { Nil }
  method description(--> Str) { self.^name }
}

class BeMatcher does Matcher is export {
  has $.expected;

  method matches($actual --> Bool) {
    ?($actual ~~ $!expected);
  }

  method expected-value(--> Mu) { $!expected }

  method description(--> Str) { 'be ' ~ $!expected.raku }
}
