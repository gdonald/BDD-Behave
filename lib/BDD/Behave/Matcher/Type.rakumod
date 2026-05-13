unit module BDD::Behave::Matcher::Type;

use BDD::Behave::Matcher;

class BeAMatcher does Matcher is export {
  has Mu $.type is required;

  method matches($actual --> Bool) {
    ?($actual ~~ $!type);
  }

  method type-name(--> Str) {
    $!type.^name;
  }

  method failure-message($actual --> Str) {
    "expected " ~ $actual.raku ~ " to be a " ~ self.type-name;
  }

  method failure-message-negated($actual --> Str) {
    "expected " ~ $actual.raku ~ " not to be a " ~ self.type-name;
  }

  method expected-value(--> Mu) { $!type }

  method description(--> Str) { 'be a ' ~ self.type-name }
}

class BeAnInstanceOfMatcher does Matcher is export {
  has Mu $.type is required;

  method matches($actual --> Bool) {
    ?($actual.defined && $actual.WHAT === $!type);
  }

  method type-name(--> Str) {
    $!type.^name;
  }

  method failure-message($actual --> Str) {
    "expected " ~ $actual.raku ~ " to be an instance of " ~ self.type-name;
  }

  method failure-message-negated($actual --> Str) {
    "expected " ~ $actual.raku ~ " not to be an instance of " ~ self.type-name;
  }

  method expected-value(--> Mu) { $!type }

  method description(--> Str) { 'be an instance of ' ~ self.type-name }
}

class RespondToMatcher does Matcher is export {
  has $.expected;

  method !missing($actual) {
    $!expected.list.grep({ !$actual.^can($_.Str) });
  }

  method matches($actual --> Bool) {
    ?(self!missing($actual).elems == 0);
  }

  method format-expected(--> Str) {
    $!expected.list.map(*.raku).join(', ');
  }

  method failure-message($actual --> Str) {
    my @missing = self!missing($actual);
    my $head    = "expected " ~ $actual.raku ~ " to respond to "
                ~ self.format-expected;
    @missing.elems
      ?? $head ~ " (missing: " ~ @missing.map(*.raku).join(', ') ~ ")"
      !! $head;
  }

  method failure-message-negated($actual --> Str) {
    "expected " ~ $actual.raku ~ " not to respond to " ~ self.format-expected;
  }

  method expected-value(--> Mu) { $!expected }

  method description(--> Str) { 'respond to ' ~ self.format-expected }
}

class HaveAttributesMatcher does Matcher is export {
  has %.expected;

  method !sorted-names() {
    %!expected.keys.sort;
  }

  method !missing($actual) {
    self!sorted-names.grep({ !$actual.^can($_) });
  }

  method !mismatches($actual) {
    my @result;
    for self!sorted-names -> $name {
      next unless $actual.^can($name);
      my $expected-value = %!expected{$name};
      my $actual-value   = $actual."$name"();

      my $passed = $expected-value ~~ Matcher
        ?? $expected-value.matches($actual-value)
        !! ($actual-value eqv $expected-value);

      unless $passed {
        @result.push: %(
          :name($name),
          :actual($actual-value),
          :expected($expected-value),
        );
      }
    }
    @result;
  }

  method matches($actual --> Bool) {
    return False unless $actual.defined;
    return False if self!missing($actual).elems;
    self!mismatches($actual).elems == 0;
  }

  method format-expected(--> Str) {
    self!sorted-names.map({
      my $v = %!expected{$_};
      my $rendered = $v ~~ Matcher ?? $v.description !! $v.raku;
      "$_ => $rendered";
    }).join(', ');
  }

  method failure-message($actual --> Str) {
    my $head    = "expected " ~ $actual.raku ~ " to have attributes "
                ~ self.format-expected;
    my @parts;

    my @missing = self!missing($actual);
    if @missing.elems {
      @parts.push: "missing: " ~ @missing.map(*.raku).join(', ');
    }

    my @mismatched = self!mismatches($actual);
    if @mismatched.elems {
      my $detail = @mismatched.map({
        my $exp = $_<expected>;
        my $rendered = $exp ~~ Matcher ?? $exp.description !! $exp.raku;
        $_<name> ~ ": got " ~ $_<actual>.raku ~ ", wanted " ~ $rendered;
      }).join('; ');
      @parts.push: "mismatched: " ~ $detail;
    }

    @parts.elems
      ?? $head ~ " (" ~ @parts.join('; ') ~ ")"
      !! $head;
  }

  method failure-message-negated($actual --> Str) {
    "expected " ~ $actual.raku ~ " not to have attributes "
      ~ self.format-expected;
  }

  method expected-value(--> Mu) { %!expected }

  method description(--> Str) {
    'have attributes ' ~ self.format-expected;
  }
}
