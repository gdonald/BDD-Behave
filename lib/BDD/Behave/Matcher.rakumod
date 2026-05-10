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
