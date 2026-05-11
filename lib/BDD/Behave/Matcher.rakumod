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
