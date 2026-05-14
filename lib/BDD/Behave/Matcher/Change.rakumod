unit module BDD::Behave::Matcher::Change;

use BDD::Behave::Matcher;

class ChangeMatcher does Matcher is export {
  has &.observable is required;
  has $.before-value          is rw;
  has $.after-value           is rw;
  has Bool $.callable-given   is rw = True;
  has Bool $.action-ran       is rw = False;
  has      $.expected-from    is rw;
  has Bool $.has-from         is rw = False;
  has      $.expected-to      is rw;
  has Bool $.has-to           is rw = False;
  has Str  $.miss-reason      is rw;

  method matches($actual --> Bool) {
    $!before-value   = Nil;
    $!after-value    = Nil;
    $!action-ran     = False;
    $!miss-reason    = Str;
    $!callable-given = ?($actual ~~ Callable);
    return self.check-captured unless $!callable-given;

    $!before-value = &!observable.();
    $actual.();
    $!action-ran   = True;
    $!after-value  = &!observable.();

    self.check-captured;
  }

  method check-captured(--> Bool) {
    unless $!callable-given {
      $!miss-reason = 'non-callable';
      return False;
    }

    if $!has-from && !($!before-value eqv $!expected-from) {
      $!miss-reason = 'from';
      return False;
    }

    if $!has-to && !($!after-value eqv $!expected-to) {
      $!miss-reason = 'to';
      return False;
    }

    if $!before-value eqv $!after-value {
      $!miss-reason = 'no-change';
      return False;
    }

    $!miss-reason = Str;
    True;
  }

  method from-to-clause(--> Str) {
    my $clause = '';
    $clause ~= ' from ' ~ $!expected-from.raku if $!has-from;
    $clause ~= ' to '   ~ $!expected-to.raku   if $!has-to;
    $clause;
  }

  method failure-message($actual --> Str) {
    given $!miss-reason {
      when 'non-callable' {
        return "expected a Callable for change, but got " ~ $actual.raku;
      }
      when 'from' {
        return "expected block to change observable" ~ self.from-to-clause
          ~ ", but it started as " ~ $!before-value.raku;
      }
      when 'to' {
        return "expected block to change observable" ~ self.from-to-clause
          ~ ", but it ended as " ~ $!after-value.raku;
      }
    }
    "expected block to change observable" ~ self.from-to-clause
      ~ ", but it remained " ~ $!before-value.raku;
  }

  method failure-message-negated($actual --> Str) {
    "expected block not to change observable" ~ self.from-to-clause
      ~ ", but it changed from " ~ $!before-value.raku
      ~ " to " ~ $!after-value.raku;
  }

  method description(--> Str) { 'change observable' ~ self.from-to-clause }

  method expected-value(--> Mu) {
    return [$!expected-from, $!expected-to] if $!has-from && $!has-to;
    return $!expected-from if $!has-from;
    return $!expected-to   if $!has-to;
    Nil;
  }
}
