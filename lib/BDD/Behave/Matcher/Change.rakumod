unit module BDD::Behave::Matcher::Change;

use BDD::Behave::Matcher;

class ChangeMatcher does Matcher is export {
  has &.observable is required;
  has $.before-value             is rw;
  has $.after-value              is rw;
  has Bool $.callable-given      is rw = True;
  has Bool $.action-ran          is rw = False;
  has      $.expected-from       is rw;
  has Bool $.has-from            is rw = False;
  has      $.expected-to         is rw;
  has Bool $.has-to              is rw = False;
  has      $.expected-by         is rw;
  has Bool $.has-by              is rw = False;
  has      $.expected-by-at-least is rw;
  has Bool $.has-by-at-least     is rw = False;
  has      $.expected-by-at-most is rw;
  has Bool $.has-by-at-most      is rw = False;
  has Str  $.miss-reason         is rw;

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

  method has-by-modifier(--> Bool) {
    ?($!has-by || $!has-by-at-least || $!has-by-at-most);
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

    if self.has-by-modifier {
      unless $!before-value ~~ Real && $!after-value ~~ Real {
        $!miss-reason = 'by-non-numeric';
        return False;
      }
      my $delta = $!after-value - $!before-value;
      if $!has-by && !($delta == $!expected-by) {
        $!miss-reason = 'by';
        return False;
      }
      if $!has-by-at-least && !($delta >= $!expected-by-at-least) {
        $!miss-reason = 'by-at-least';
        return False;
      }
      if $!has-by-at-most && !($delta <= $!expected-by-at-most) {
        $!miss-reason = 'by-at-most';
        return False;
      }
    }

    $!miss-reason = Str;
    True;
  }

  method change-clause(--> Str) {
    my $clause = '';
    $clause ~= ' from ' ~ $!expected-from.raku             if $!has-from;
    $clause ~= ' to '   ~ $!expected-to.raku               if $!has-to;
    $clause ~= ' by '   ~ $!expected-by.raku               if $!has-by;
    $clause ~= ' by at least ' ~ $!expected-by-at-least.raku if $!has-by-at-least;
    $clause ~= ' by at most '  ~ $!expected-by-at-most.raku  if $!has-by-at-most;
    $clause;
  }

  method delta(--> Mu) {
    return Nil unless $!before-value ~~ Real && $!after-value ~~ Real;
    $!after-value - $!before-value;
  }

  method failure-message($actual --> Str) {
    given $!miss-reason {
      when 'non-callable' {
        return "expected a Callable for change, but got " ~ $actual.raku;
      }
      when 'from' {
        return "expected block to change observable" ~ self.change-clause
          ~ ", but it started as " ~ $!before-value.raku;
      }
      when 'to' {
        return "expected block to change observable" ~ self.change-clause
          ~ ", but it ended as " ~ $!after-value.raku;
      }
      when 'by' | 'by-at-least' | 'by-at-most' {
        return "expected block to change observable" ~ self.change-clause
          ~ ", but it changed by " ~ self.delta.raku;
      }
      when 'by-non-numeric' {
        return "expected block to change observable" ~ self.change-clause
          ~ ", but values were not numeric (before: "
          ~ $!before-value.raku ~ ", after: " ~ $!after-value.raku ~ ")";
      }
    }
    "expected block to change observable" ~ self.change-clause
      ~ ", but it remained " ~ $!before-value.raku;
  }

  method failure-message-negated($actual --> Str) {
    "expected block not to change observable" ~ self.change-clause
      ~ ", but it changed from " ~ $!before-value.raku
      ~ " to " ~ $!after-value.raku;
  }

  method description(--> Str) { 'change observable' ~ self.change-clause }

  method expected-value(--> Mu) {
    return [$!expected-from, $!expected-to] if $!has-from && $!has-to;
    return $!expected-from        if $!has-from;
    return $!expected-to          if $!has-to;
    return $!expected-by          if $!has-by;
    return $!expected-by-at-least if $!has-by-at-least;
    return $!expected-by-at-most  if $!has-by-at-most;
    Nil;
  }
}
