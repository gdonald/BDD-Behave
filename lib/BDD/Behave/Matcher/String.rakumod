unit module BDD::Behave::Matcher::String;

use BDD::Behave::Matcher;

class MatchMatcher does Matcher is export {
  has Regex $.expected is required;

  method matches($actual --> Bool) {
    return False unless $actual.defined;
    return False unless $actual ~~ Str;
    ?($actual ~~ $!expected);
  }

  method failure-message($actual --> Str) {
    "expected " ~ $actual.raku ~ " to match " ~ $!expected.raku;
  }

  method failure-message-negated($actual --> Str) {
    "expected " ~ $actual.raku ~ " not to match " ~ $!expected.raku;
  }

  method expected-value(--> Mu) { $!expected }

  method description(--> Str) { 'match ' ~ $!expected.raku }
}
