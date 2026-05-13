unit module BDD::Behave::Matcher::Change;

use BDD::Behave::Matcher;

class ChangeMatcher does Matcher is export {
  has &.observable is required;
  has $.before-value          is rw;
  has $.after-value           is rw;
  has Bool $.callable-given   is rw = True;
  has Bool $.action-ran       is rw = False;

  method matches($actual --> Bool) {
    $!before-value   = Nil;
    $!after-value    = Nil;
    $!action-ran     = False;
    $!callable-given = ?($actual ~~ Callable);
    return False unless $!callable-given;

    $!before-value = &!observable.();
    $actual.();
    $!action-ran   = True;
    $!after-value  = &!observable.();

    !($!before-value eqv $!after-value);
  }

  method failure-message($actual --> Str) {
    unless $!callable-given {
      return "expected a Callable for change, but got " ~ $actual.raku;
    }
    "expected block to change observable, but it remained "
      ~ $!before-value.raku;
  }

  method failure-message-negated($actual --> Str) {
    "expected block not to change observable, but it changed from "
      ~ $!before-value.raku ~ " to " ~ $!after-value.raku;
  }

  method description(--> Str) { 'change observable' }
}
