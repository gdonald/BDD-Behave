unit module BDD::Behave::Mock::HaveReceived;

use BDD::Behave::Failure;
use BDD::Behave::Failures;
use BDD::Behave::Mock::ArgMatcher;
use BDD::Behave::Mock::Double;
use BDD::Behave::Mock::Stub;

class HaveReceivedExpectation is export {
  has Mu       $.target;
  has Str      $.method-name is required;
  has Bool     $.negated     = False;
  has Str      $.file        is required;
  has Int      $.line        is required;
  has Bool     $!has-with-filter = False;
  has @!with-args;
  has %!with-named;
  has Str      $!count-kind  = 'present';
  has Int      $!count-n     = 0;
  has          $!recorded-failure;

  submethod BUILD(Mu :$target is raw, :$!method-name, :$!negated, :$!file, :$!line) {
    $!target := $target;
  }

  method calls() {
    if $!target.WHAT === Double {
      return $!target.calls-of($!method-name);
    }

    my $stub = StubRegistry.find-existing($!target, $!method-name);
    return $stub.defined ?? $stub.calls-of($!method-name) !! ();
  }

  method has-recorder(--> Bool) {
    return True if $!target.WHAT === Double;
    StubRegistry.find-existing($!target, $!method-name).defined;
  }

  method match-call(Call $c --> Bool) {
    return True unless $!has-with-filter;
    return False unless @!with-args.elems == $c.args.elems;
    for @!with-args.kv -> $i, $expected {
      my $actual = $c.args[$i];
      if $expected ~~ ArgMatcher {
        return False unless $expected.matches($actual);
      } else {
        return False unless $actual ~~ $expected;
      }
    }
    for %!with-named.kv -> $k, $expected {
      return False unless $c.named{$k}:exists;
      my $actual = $c.named{$k};
      if $expected ~~ ArgMatcher {
        return False unless $expected.matches($actual);
      } else {
        return False unless $actual ~~ $expected;
      }
    }
    True;
  }

  method matching-calls() {
    self.calls.grep({ self.match-call($_) }).List;
  }

  method count-met(Int $count --> Bool) {
    given $!count-kind {
      when 'present'  { return $count > 0 }
      when 'exactly'  { return $count == $!count-n }
      when 'at-least' { return $count >= $!count-n }
      when 'at-most'  { return $count <= $!count-n }
    }
    False;
  }

  method count-clause(--> Str) {
    given $!count-kind {
      when 'present'  { 'at least once' }
      when 'exactly'  {
        $!count-n == 1 ?? 'exactly once'
        !! $!count-n == 2 ?? 'exactly twice'
        !! "exactly {$!count-n} times"
      }
      when 'at-least' {
        $!count-n == 1 ?? 'at least once'
        !! "at least {$!count-n} times"
      }
      when 'at-most'  {
        $!count-n == 1 ?? 'at most once'
        !! "at most {$!count-n} times"
      }
      default { 'at least once' }
    }
  }

  method args-clause(--> Str) {
    return '' unless $!has-with-filter;
    my @parts;
    for @!with-args -> $a {
      @parts.push: $a ~~ ArgMatcher ?? $a.describe !! $a.raku;
    }
    for %!with-named.kv -> $k, $v {
      my $val = $v ~~ ArgMatcher ?? $v.describe !! $v.raku;
      @parts.push: ":$k\($val)";
    }
    " with ({@parts.join(', ')})";
  }

  method target-description(--> Str) {
    if $!target.WHAT === Double {
      my $name = $!target.double-name;
      return "double($name.raku())#{$!method-name}";
    }
    my $owner = ($!target.defined && $!target.DEFINITE) ?? $!target.WHAT !! $!target;
    "{$owner.^name}#{$!method-name}";
  }

  method validate(--> Nil) {
    unless self.has-recorder {
      my $msg = "expect({self.target-description}).to.have-received(...): "
              ~ "no stub installed; call `allow($!target.^name())"
              ~ ".to.receive('{$!method-name}')` first or use `spy(\$obj)`";
      self.replace-failure($msg);
      return;
    }

    my @matches = self.matching-calls;
    my $count   = @matches.elems;
    my $met     = self.count-met($count);
    $met = !$met if $!negated;

    if $met {
      self.clear-failure;
      return;
    }

    my $verb = $!negated ?? 'not to have been called' !! 'to have been called';
    my $expected = self.count-clause ~ self.args-clause;
    my $actual-clause = self.actual-clause($count);

    my $msg = "expected {self.target-description} $verb $expected\n     got $actual-clause";
    self.replace-failure($msg);
  }

  method actual-clause(Int $observed --> Str) {
    my $total = self.calls.elems;
    if $!has-with-filter {
      return "$observed matching call{$observed == 1 ?? '' !! 's'} (out of $total total)";
    }
    "$total call{$total == 1 ?? '' !! 's'}";
  }

  method replace-failure(Str $msg --> Nil) {
    self.clear-failure;
    my $f = Failure.new(
      :$!file, :$!line, :message($msg), :negated($!negated),
    );
    Failures.list.push($f);
    $!recorded-failure = $f;
  }

  method clear-failure(--> Nil) {
    return unless $!recorded-failure.defined;
    my $list = Failures.list;
    my $idx  = $list.first({ $_ === $!recorded-failure }, :k);
    $list.splice($idx, 1) if $idx.defined;
    $!recorded-failure = Nil;
  }

  method with(*@a, *%n) {
    @!with-args = @a;
    %!with-named = %n;
    $!has-with-filter = True;
    self.validate;
    self;
  }

  method times(Int:D $n) {
    $!count-kind = 'exactly';
    $!count-n    = $n;
    self.validate;
    self;
  }

  method exactly(Int:D $n)  { self.times($n) }
  method once               { self.times(1) }
  method twice              { self.times(2) }
  method thrice             { self.times(3) }

  method at-least(Int:D $n) {
    $!count-kind = 'at-least';
    $!count-n    = $n;
    self.validate;
    self;
  }

  method at-most(Int:D $n) {
    $!count-kind = 'at-most';
    $!count-n    = $n;
    self.validate;
    self;
  }
}
