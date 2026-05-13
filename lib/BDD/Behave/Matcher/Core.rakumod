unit module BDD::Behave::Matcher::Core;

use BDD::Behave::Matcher;

class BeMatcher does Matcher is export {
  has $.expected;

  method matches($actual --> Bool) {
    ?($actual ~~ $!expected);
  }

  method expected-value(--> Mu) { $!expected }

  method description(--> Str) { 'be ' ~ $!expected.raku }
}

class EqMatcher does Matcher is export {
  has $.expected;

  method matches($actual --> Bool) {
    ?($actual eqv $!expected);
  }

  method expected-value(--> Mu) { $!expected }

  method description(--> Str) { 'eq ' ~ $!expected.raku }
}
