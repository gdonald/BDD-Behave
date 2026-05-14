unit module BDD::Behave::Expectation;

use BDD::Behave::Failure;
use BDD::Behave::Failures;
use BDD::Behave::Matcher;
use BDD::Behave::Matcher::Core;
use BDD::Behave::Matcher::Collection;
use BDD::Behave::Matcher::Type;
use BDD::Behave::Matcher::Numeric;
use BDD::Behave::Matcher::Boolean;
use BDD::Behave::Matcher::String;
use BDD::Behave::Matcher::Exception;
use BDD::Behave::Matcher::Change;
use BDD::Behave::Matcher::Custom;
use BDD::Behave::Mock::HaveReceived;

class BetweenExpectation is export {
  has Mu   $.given;
  has Bool $.negated = False;
  has Str  $.file;
  has Int  $.line;
  has      $.min;
  has      $.max;
  has Bool $!exclusive = False;
  has      $!recorded-failure;

  submethod BUILD(
    Mu :$given is raw, :$!negated, :$!file, :$!line, :$!min, :$!max,
  ) {
    $!given := $given;
  }

  method validate(--> Nil) {
    my $matcher = BeBetweenMatcher.new(
      :min($!min), :max($!max), :exclusive($!exclusive),
    );
    my $matched = ?$matcher.matches($!given);
    my $passed  = $!negated ?? !$matched !! $matched;

    if $passed {
      self.clear-failure;
      return;
    }

    my $message = $!negated
      ?? $matcher.failure-message-negated($!given)
      !! $matcher.failure-message($!given);

    self.replace-failure($message, $matcher);
  }

  method replace-failure(Str $msg, $matcher --> Nil) {
    self.clear-failure;
    my $f = Failure.new(
      :file($!file),
      :line($!line),
      :given($!given),
      :expected($matcher.expected-value),
      :negated($!negated),
      :message($msg),
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

  method inclusive {
    $!exclusive = False;
    self.validate;
    self;
  }

  method exclusive {
    $!exclusive = True;
    self.validate;
    self;
  }
}

class WithinExpectation is export {
  has Mu   $.given;
  has Bool $.negated = False;
  has Str  $.file;
  has Int  $.line;
  has      $.delta;

  submethod BUILD(
    Mu :$given is raw, :$!negated, :$!file, :$!line, :$!delta,
  ) {
    $!given := $given;
  }

  method of($expected --> Nil) {
    my $matcher = BeWithinMatcher.new(:delta($!delta), :$expected);
    my $matched = ?$matcher.matches($!given);
    my $passed  = $!negated ?? !$matched !! $matched;
    return if $passed;

    my $message = $!negated
      ?? $matcher.failure-message-negated($!given)
      !! $matcher.failure-message($!given);

    my $f = Failure.new(
      :file($!file),
      :line($!line),
      :given($!given),
      :expected($matcher.expected-value),
      :negated($!negated),
      :message($message),
    );
    Failures.list.push($f);
  }
}

class ChangeExpectation is export {
  has Mu   $.given;
  has      &.observable;
  has Bool $.negated = False;
  has Str  $.file;
  has Int  $.line;
  has      $!expected-from;
  has Bool $!has-from = False;
  has      $!expected-to;
  has Bool $!has-to = False;
  has      $!expected-by;
  has Bool $!has-by = False;
  has      $!expected-by-at-least;
  has Bool $!has-by-at-least = False;
  has      $!expected-by-at-most;
  has Bool $!has-by-at-most = False;
  has      $!before-value;
  has      $!after-value;
  has Bool $!callable-given = True;
  has Bool $!ran = False;
  has Bool $!passed = False;
  has      $!recorded-failure;

  submethod BUILD(
    Mu :$given is raw, :&observable, :$!negated, :$!file, :$!line,
  ) {
    $!given      := $given;
    &!observable  = &observable;
  }

  method !run-block(--> Nil) {
    return if $!ran;
    $!ran = True;
    $!callable-given = ?($!given ~~ Callable);
    return unless $!callable-given;
    $!before-value = &!observable.();
    $!given.();
    $!after-value  = &!observable.();
  }

  method !build-matcher() {
    my $m = ChangeMatcher.new(:&!observable);
    $m.callable-given      = $!callable-given;
    $m.action-ran          = $!callable-given;
    $m.before-value        = $!before-value;
    $m.after-value         = $!after-value;
    $m.expected-from       = $!expected-from;
    $m.has-from            = $!has-from;
    $m.expected-to         = $!expected-to;
    $m.has-to              = $!has-to;
    $m.expected-by         = $!expected-by;
    $m.has-by              = $!has-by;
    $m.expected-by-at-least = $!expected-by-at-least;
    $m.has-by-at-least     = $!has-by-at-least;
    $m.expected-by-at-most = $!expected-by-at-most;
    $m.has-by-at-most      = $!has-by-at-most;
    $m;
  }

  method validate(--> Nil) {
    self!run-block;
    my $matcher = self!build-matcher;
    my $matched = ?$matcher.check-captured;
    $!passed = $!negated ?? !$matched !! $matched;

    try {
      if $*BEHAVE-AUTO-MATCHERS.defined {
        $*BEHAVE-AUTO-MATCHERS.push(%(:$matcher, :negated($!negated)));
      }
    }

    if $!passed {
      self.clear-failure;
      return;
    }

    my $message = $!negated
      ?? $matcher.failure-message-negated($!given)
      !! $matcher.failure-message($!given);

    self.replace-failure($message, $matcher);
  }

  method replace-failure(Str $msg, $matcher --> Nil) {
    self.clear-failure;
    my $f = Failure.new(
      :file($!file),
      :line($!line),
      :given($!given),
      :expected($matcher.expected-value),
      :negated($!negated),
      :message($msg),
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

  method from(Mu \value) {
    $!expected-from := value;
    $!has-from = True;
    self.validate;
    self;
  }

  method to(Mu \value) {
    $!expected-to := value;
    $!has-to = True;
    self.validate;
    self;
  }

  method by(Mu \value) {
    $!expected-by := value;
    $!has-by = True;
    self.validate;
    self;
  }

  method by-at-least(Mu \value) {
    $!expected-by-at-least := value;
    $!has-by-at-least = True;
    self.validate;
    self;
  }

  method by-at-most(Mu \value) {
    $!expected-by-at-most := value;
    $!has-by-at-most = True;
    self.validate;
    self;
  }

  method Bool(--> Bool) { $!passed }
}

class RaiseErrorExpectation is export {
  has Mu   $.given;
  has Bool $.negated = False;
  has Str  $.file;
  has Int  $.line;
  has Mu   $.expected-type;
  has Bool $.has-type = False;
  has      $!expected-message;
  has Mu   $!raised-exception;
  has Bool $!callable-given = True;
  has Bool $!ran = False;
  has Bool $!passed = False;
  has      $!recorded-failure;

  submethod BUILD(
    Mu :$given is raw, :$!negated, :$!file, :$!line,
    Mu :$expected-type, Bool :$has-type, :$expected-message,
  ) {
    $!given             := $given;
    $!expected-type     := $expected-type;
    $!has-type           = ?$has-type;
    $!expected-message   = $expected-message;
  }

  method !run-block(--> Nil) {
    return if $!ran;
    $!ran = True;
    $!callable-given = ?($!given ~~ Callable);
    return unless $!callable-given;
    try {
      $!given.();
      CATCH { default { $!raised-exception = $_; } }
    }
  }

  method !build-matcher() {
    my $m = RaiseErrorMatcher.new(
      :expected-type($!expected-type),
      :$!has-type,
      :expected-message($!expected-message),
    );
    $m.callable-given   = $!callable-given;
    $m.raised-exception = $!raised-exception;
    $m;
  }

  method validate(--> Nil) {
    self!run-block;
    my $matcher = self!build-matcher;
    my $matched = ?$matcher.check-captured;
    $!passed = $!negated ?? !$matched !! $matched;

    try {
      if $*BEHAVE-AUTO-MATCHERS.defined {
        $*BEHAVE-AUTO-MATCHERS.push(%(:$matcher, :negated($!negated)));
      }
    }

    if $!passed {
      self.clear-failure;
      return;
    }

    my $message = $!negated
      ?? $matcher.failure-message-negated($!given)
      !! $matcher.failure-message($!given);

    self.replace-failure($message, $matcher);
  }

  method replace-failure(Str $msg, $matcher --> Nil) {
    self.clear-failure;
    my $f = Failure.new(
      :file($!file),
      :line($!line),
      :given($!given),
      :expected($matcher.expected-value),
      :negated($!negated),
      :message($msg),
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

  proto method with-message(|) {*}

  multi method with-message(Regex $message) {
    $!expected-message = $message;
    self.validate;
    self;
  }

  multi method with-message(Str:D $message) {
    $!expected-message = $message;
    self.validate;
    self;
  }

  method Bool(--> Bool) { $!passed }
}

class ExpectationBuilder is export {
  has $.given;
  has Bool $.negated is rw = False;
  has Int $.line;
  has Str $.file;

  method to { self }

  method not {
    my $new = ExpectationBuilder.new(
      :given($!given),
      :negated(True),
      :line($!line),
      :file($!file)
    );
    $new;
  }

  method !apply-matcher($matcher) {
    try {
      if $*BEHAVE-AUTO-MATCHERS.defined {
        $*BEHAVE-AUTO-MATCHERS.push(%(:$matcher, :negated($!negated)));
      }
    }

    my $matched = ?$matcher.matches($!given);
    my $passed  = $!negated ?? !$matched !! $matched;

    if !$passed {
      my $message = $!negated
        ?? $matcher.failure-message-negated($!given)
        !! $matcher.failure-message($!given);

      my $expected-for-failure = $matcher ~~ BeMatcher
        ?? $matcher.expected
        !! $matcher.expected-value;

      my $failure = Failure.new(
        :file($!file),
        :line($!line),
        :given($!given),
        :expected($expected-for-failure),
        :negated($!negated),
        :message($message),
      );
      Failures.list.push($failure);
    }

    $passed;
  }

  method be(|c) {
    my @pos = c.list;
    my %named = c.hash;

    my $resolved-expected;
    if %named.elems == 1 && @pos.elems == 0 {
      my $key = %named.keys[0];
      try {
        $resolved-expected = $*LET-RUNTIME.value($key) if $*LET-RUNTIME.defined;
        CATCH {
          default {
            die "Unknown let(:$key)";
          }
        }
      }
    } elsif @pos.elems == 1 {
      my $expected = @pos[0];

      $resolved-expected = $expected;
      if $expected ~~ Pair {
        try {
          $resolved-expected = $*LET-RUNTIME.value($expected.key) if $*LET-RUNTIME.defined;
        }
      }
    } else {
      die "be requires either a positional argument or a single named argument";
    }

    my $matcher = $resolved-expected ~~ Matcher
      ?? $resolved-expected
      !! BeMatcher.new(:expected($resolved-expected));

    self!apply-matcher($matcher);
  }

  method include(**@items, *%pairs) {
    my @expected = @items;
    @expected.append: %pairs.pairs;
    if @expected.elems == 0 {
      die "include requires at least one item";
    }
    self!apply-matcher(IncludeMatcher.new(:expected(@expected)));
  }

  method eq($expected) {
    self!apply-matcher(EqMatcher.new(:expected($expected)));
  }

  method contain-exactly(**@items) {
    self!apply-matcher(ContainExactlyMatcher.new(:expected(@items)));
  }

  method match-array($expected) {
    unless $expected ~~ Positional | Iterable {
      die "match-array requires an array argument";
    }
    self!apply-matcher(ContainExactlyMatcher.new(:expected($expected.list)));
  }

  method start-with(**@items) {
    if @items.elems == 0 {
      die "start-with requires at least one item";
    }
    self!apply-matcher(StartWithMatcher.new(:expected(@items)));
  }

  method end-with(**@items) {
    if @items.elems == 0 {
      die "end-with requires at least one item";
    }
    self!apply-matcher(EndWithMatcher.new(:expected(@items)));
  }

  method all(Mu \expected) {
    my $inner = expected ~~ Matcher
      ?? expected
      !! BeMatcher.new(:expected(expected));
    self!apply-matcher(AllMatcher.new(:inner($inner)));
  }

  method be-a(Mu \type) {
    self!apply-matcher(BeAMatcher.new(:type(type)));
  }

  method be-an(Mu \type) {
    self!apply-matcher(BeAMatcher.new(:type(type)));
  }

  method be-an-instance-of(Mu \type) {
    self!apply-matcher(BeAnInstanceOfMatcher.new(:type(type)));
  }

  method respond-to(**@names) {
    if @names.elems == 0 {
      die "respond-to requires at least one method name";
    }
    self!apply-matcher(RespondToMatcher.new(:expected(@names)));
  }

  method have-attributes(*%attrs) {
    if %attrs.elems == 0 {
      die "have-attributes requires at least one attribute name => value pair";
    }
    self!apply-matcher(HaveAttributesMatcher.new(:expected(%attrs)));
  }

  method be-greater-than($expected) {
    self!apply-matcher(BeGreaterThanMatcher.new(:$expected));
  }

  method be-gt($expected) {
    self!apply-matcher(BeGreaterThanMatcher.new(:$expected));
  }

  method be-greater-than-or-equal-to($expected) {
    self!apply-matcher(BeGreaterThanOrEqualMatcher.new(:$expected));
  }

  method be-gte($expected) {
    self!apply-matcher(BeGreaterThanOrEqualMatcher.new(:$expected));
  }

  method be-less-than($expected) {
    self!apply-matcher(BeLessThanMatcher.new(:$expected));
  }

  method be-lt($expected) {
    self!apply-matcher(BeLessThanMatcher.new(:$expected));
  }

  method be-less-than-or-equal-to($expected) {
    self!apply-matcher(BeLessThanOrEqualMatcher.new(:$expected));
  }

  method be-lte($expected) {
    self!apply-matcher(BeLessThanOrEqualMatcher.new(:$expected));
  }

  method be-between($min, $max) {
    my $expectation = BetweenExpectation.new(
      :given($!given),
      :negated($!negated),
      :file($!file),
      :line($!line),
      :$min,
      :$max,
    );
    $expectation.validate;
    $expectation;
  }

  method be-truthy() {
    self!apply-matcher(BeTruthyMatcher.new);
  }

  method be-falsy() {
    self!apply-matcher(BeFalsyMatcher.new);
  }

  method be-nil() {
    self!apply-matcher(BeNilMatcher.new);
  }

  method match(Regex $expected) {
    self!apply-matcher(MatchMatcher.new(:$expected));
  }

  method !build-raise-expectation(
    Mu :$expected-type, Bool :$has-type, :$expected-message,
  ) {
    my $expectation = RaiseErrorExpectation.new(
      :given($!given),
      :negated($!negated),
      :file($!file),
      :line($!line),
      :$expected-type,
      :$has-type,
      :$expected-message,
    );
    $expectation.validate;
    $expectation;
  }

  proto method raise-error(|) {*}

  multi method raise-error() {
    self!build-raise-expectation;
  }

  multi method raise-error(Regex $message) {
    self!build-raise-expectation(:expected-message($message));
  }

  multi method raise-error(Mu \type) {
    self!build-raise-expectation(:expected-type(type), :has-type);
  }

  multi method raise-error(Mu \type, Regex $message) {
    self!build-raise-expectation(
      :expected-type(type),
      :has-type,
      :expected-message($message),
    );
  }

  method change(&observable) {
    my $expectation = ChangeExpectation.new(
      :given($!given),
      :&observable,
      :negated($!negated),
      :file($!file),
      :line($!line),
    );
    $expectation.validate;
    $expectation;
  }

  method be-within($delta) {
    WithinExpectation.new(
      :given($!given),
      :negated($!negated),
      :file($!file),
      :line($!line),
      :$delta,
    );
  }

  method have-received(Str:D $method-name) {
    my $expectation = HaveReceivedExpectation.new(
      :target($!given),
      :$method-name,
      :negated($!negated),
      :file($!file),
      :line($!line),
    );
    $expectation.validate;
    $expectation;
  }

  method FALLBACK($name, |c) {
    my $registry = BDD::Behave::Matcher::Custom::registry();
    if $registry.exists($name) {
      my $matcher = $registry.build($name, |c);
      return self!apply-matcher($matcher);
    }
    die X::Method::NotFound.new(
      method   => $name,
      typename => self.^name,
    );
  }
}
