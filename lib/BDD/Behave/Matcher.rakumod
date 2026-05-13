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

class EqMatcher does Matcher is export {
  has $.expected;

  method matches($actual --> Bool) {
    ?($actual eqv $!expected);
  }

  method expected-value(--> Mu) { $!expected }

  method description(--> Str) { 'eq ' ~ $!expected.raku }
}

class ContainExactlyMatcher does Matcher is export {
  has $.expected;

  method matches($actual --> Bool) {
    return False unless $actual.defined;
    return False unless $actual ~~ Positional | Iterable;

    my @remaining = $actual.list;

    for $!expected.list -> $item {
      my $idx = @remaining.first({ $_ eqv $item }, :k);
      if $idx.defined {
        @remaining.splice($idx, 1);
      } else {
        return False;
      }
    }

    @remaining.elems == 0;
  }

  method format-expected(--> Str) {
    $!expected.list.map(*.raku).join(', ');
  }

  method failure-message($actual --> Str) {
    "expected " ~ $actual.raku ~ " to contain exactly " ~ self.format-expected;
  }

  method failure-message-negated($actual --> Str) {
    "expected " ~ $actual.raku ~ " not to contain exactly " ~ self.format-expected;
  }

  method expected-value(--> Mu) { $!expected }

  method description(--> Str) { 'contain exactly ' ~ self.format-expected }
}

class StartWithMatcher does Matcher is export {
  has $.expected;

  method matches($actual --> Bool) {
    return False unless $actual.defined;

    given $actual {
      when Str {
        for $!expected.list -> $item {
          return False unless $actual.starts-with($item.Str);
        }
        return True;
      }
      when Positional | Iterable {
        my @arr = $actual.list;
        my @items = $!expected.list;
        return False if @items.elems > @arr.elems;
        for @items.kv -> $i, $item {
          return False unless @arr[$i] eqv $item;
        }
        return True;
      }
      default {
        return False;
      }
    }
  }

  method format-expected(--> Str) {
    $!expected.list.map(*.raku).join(', ');
  }

  method failure-message($actual --> Str) {
    "expected " ~ $actual.raku ~ " to start with " ~ self.format-expected;
  }

  method failure-message-negated($actual --> Str) {
    "expected " ~ $actual.raku ~ " not to start with " ~ self.format-expected;
  }

  method expected-value(--> Mu) { $!expected }

  method description(--> Str) { 'start with ' ~ self.format-expected }
}

class EndWithMatcher does Matcher is export {
  has $.expected;

  method matches($actual --> Bool) {
    return False unless $actual.defined;

    given $actual {
      when Str {
        for $!expected.list -> $item {
          return False unless $actual.ends-with($item.Str);
        }
        return True;
      }
      when Positional | Iterable {
        my @arr = $actual.list;
        my @items = $!expected.list;
        return False if @items.elems > @arr.elems;
        my $offset = @arr.elems - @items.elems;
        for @items.kv -> $i, $item {
          return False unless @arr[$offset + $i] eqv $item;
        }
        return True;
      }
      default {
        return False;
      }
    }
  }

  method format-expected(--> Str) {
    $!expected.list.map(*.raku).join(', ');
  }

  method failure-message($actual --> Str) {
    "expected " ~ $actual.raku ~ " to end with " ~ self.format-expected;
  }

  method failure-message-negated($actual --> Str) {
    "expected " ~ $actual.raku ~ " not to end with " ~ self.format-expected;
  }

  method expected-value(--> Mu) { $!expected }

  method description(--> Str) { 'end with ' ~ self.format-expected }
}

class AllMatcher does Matcher is export {
  has Matcher $.inner;

  method matches($actual --> Bool) {
    return False unless $actual.defined;
    return False unless $actual ~~ Positional | Iterable;

    for $actual.list -> $item {
      return False unless $!inner.matches($item);
    }
    return True;
  }

  method !find-failing-index($actual) {
    for $actual.list.kv -> $i, $item {
      return $i unless $!inner.matches($item);
    }
    return Int;
  }

  method failure-message($actual --> Str) {
    unless $actual.defined && $actual ~~ Positional | Iterable {
      return "expected " ~ $actual.raku ~ " to be a collection that all "
           ~ $!inner.description;
    }

    my $idx = self!find-failing-index($actual);
    if $idx.defined {
      my $item = $actual.list[$idx];
      return "expected " ~ $actual.raku ~ " to all " ~ $!inner.description
           ~ " (element at index " ~ $idx ~ ": " ~ $item.raku ~ " did not match)";
    }
    "expected " ~ $actual.raku ~ " to all " ~ $!inner.description;
  }

  method failure-message-negated($actual --> Str) {
    "expected " ~ $actual.raku ~ " not to all " ~ $!inner.description;
  }

  method expected-value(--> Mu) { $!inner }

  method description(--> Str) { 'all ' ~ $!inner.description }
}

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

class BeGreaterThanMatcher does Matcher is export {
  has $.expected;

  method matches($actual --> Bool) {
    return False unless $actual.defined;
    return False unless $actual ~~ Real;
    ?($actual > $!expected);
  }

  method failure-message($actual --> Str) {
    "expected " ~ $actual.raku ~ " to be greater than " ~ $!expected.raku;
  }

  method failure-message-negated($actual --> Str) {
    "expected " ~ $actual.raku ~ " not to be greater than " ~ $!expected.raku;
  }

  method expected-value(--> Mu) { $!expected }

  method description(--> Str) { 'be greater than ' ~ $!expected.raku }
}

class BeGreaterThanOrEqualMatcher does Matcher is export {
  has $.expected;

  method matches($actual --> Bool) {
    return False unless $actual.defined;
    return False unless $actual ~~ Real;
    ?($actual >= $!expected);
  }

  method failure-message($actual --> Str) {
    "expected " ~ $actual.raku ~ " to be greater than or equal to "
      ~ $!expected.raku;
  }

  method failure-message-negated($actual --> Str) {
    "expected " ~ $actual.raku ~ " not to be greater than or equal to "
      ~ $!expected.raku;
  }

  method expected-value(--> Mu) { $!expected }

  method description(--> Str) {
    'be greater than or equal to ' ~ $!expected.raku;
  }
}

class BeLessThanMatcher does Matcher is export {
  has $.expected;

  method matches($actual --> Bool) {
    return False unless $actual.defined;
    return False unless $actual ~~ Real;
    ?($actual < $!expected);
  }

  method failure-message($actual --> Str) {
    "expected " ~ $actual.raku ~ " to be less than " ~ $!expected.raku;
  }

  method failure-message-negated($actual --> Str) {
    "expected " ~ $actual.raku ~ " not to be less than " ~ $!expected.raku;
  }

  method expected-value(--> Mu) { $!expected }

  method description(--> Str) { 'be less than ' ~ $!expected.raku }
}

class BeLessThanOrEqualMatcher does Matcher is export {
  has $.expected;

  method matches($actual --> Bool) {
    return False unless $actual.defined;
    return False unless $actual ~~ Real;
    ?($actual <= $!expected);
  }

  method failure-message($actual --> Str) {
    "expected " ~ $actual.raku ~ " to be less than or equal to "
      ~ $!expected.raku;
  }

  method failure-message-negated($actual --> Str) {
    "expected " ~ $actual.raku ~ " not to be less than or equal to "
      ~ $!expected.raku;
  }

  method expected-value(--> Mu) { $!expected }

  method description(--> Str) {
    'be less than or equal to ' ~ $!expected.raku;
  }
}

class BeBetweenMatcher does Matcher is export {
  has $.min;
  has $.max;
  has Bool $.exclusive = False;

  method matches($actual --> Bool) {
    return False unless $actual.defined;
    return False unless $actual ~~ Real;
    if $!exclusive {
      ?($actual > $!min && $actual < $!max);
    } else {
      ?($actual >= $!min && $actual <= $!max);
    }
  }

  method bounds-clause(--> Str) {
    $!exclusive
      ?? $!min.raku ~ ' and ' ~ $!max.raku ~ ' (exclusive)'
      !! $!min.raku ~ ' and ' ~ $!max.raku ~ ' (inclusive)';
  }

  method failure-message($actual --> Str) {
    "expected " ~ $actual.raku ~ " to be between " ~ self.bounds-clause;
  }

  method failure-message-negated($actual --> Str) {
    "expected " ~ $actual.raku ~ " not to be between " ~ self.bounds-clause;
  }

  method expected-value(--> Mu) { [$!min, $!max] }

  method description(--> Str) { 'be between ' ~ self.bounds-clause }
}

class BeWithinMatcher does Matcher is export {
  has $.delta;
  has $.expected;

  method matches($actual --> Bool) {
    return False unless $actual.defined;
    return False unless $actual ~~ Real;
    return False unless $!expected.defined;
    return False unless $!expected ~~ Real;
    ?(abs($actual - $!expected) <= $!delta);
  }

  method failure-message($actual --> Str) {
    "expected " ~ $actual.raku ~ " to be within " ~ $!delta.raku
      ~ " of " ~ $!expected.raku;
  }

  method failure-message-negated($actual --> Str) {
    "expected " ~ $actual.raku ~ " not to be within " ~ $!delta.raku
      ~ " of " ~ $!expected.raku;
  }

  method expected-value(--> Mu) { $!expected }

  method description(--> Str) {
    'be within ' ~ $!delta.raku ~ ' of ' ~ $!expected.raku;
  }
}

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

class IncludeMatcher does Matcher is export {
  has $.expected;

  method matches($actual --> Bool) {
    return False unless $actual.defined;

    given $actual {
      when Str {
        for $!expected.list -> $item {
          return False unless $actual.contains($item.Str);
        }
        return True;
      }
      when Setty | Baggy {
        for $!expected.list -> $item {
          return False unless $actual{$item};
        }
        return True;
      }
      when Associative {
        for $!expected.list -> $item {
          if $item ~~ Pair {
            return False unless $actual{$item.key}:exists;
            return False unless $actual{$item.key} eqv $item.value;
          } else {
            return False unless $actual{$item}:exists;
          }
        }
        return True;
      }
      when Positional | Iterable {
        my @arr = $actual.list;
        for $!expected.list -> $item {
          return False unless @arr.first({ $_ eqv $item }).defined;
        }
        return True;
      }
      default {
        return False;
      }
    }
  }

  method format-expected(--> Str) {
    $!expected.list.map(*.raku).join(', ');
  }

  method failure-message($actual --> Str) {
    "expected " ~ $actual.raku ~ " to include " ~ self.format-expected;
  }

  method failure-message-negated($actual --> Str) {
    "expected " ~ $actual.raku ~ " not to include " ~ self.format-expected;
  }

  method expected-value(--> Mu) { $!expected }

  method description(--> Str) { 'include ' ~ self.format-expected }
}
