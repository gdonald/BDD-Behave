unit module BDD::Behave::Matcher;

role Matcher is export {
  method matches($actual --> Bool) { ... }
  method failure-message($actual --> Str) { Str }
  method failure-message-negated($actual --> Str) { Str }
  method expected-value(--> Mu) { Nil }
  method description(--> Str) { self.^name }

  method and($other, *@rest) {
    my @others = ($other, |@rest);
    for @others -> $m {
      unless $m ~~ Matcher {
        die "Matcher.and requires Matcher arguments";
      }
    }
    ::('BDD::Behave::Matcher::AndMatcher').new(
      :matchers((self, |@others).flat.List),
    );
  }

  method or($other, *@rest) {
    my @others = ($other, |@rest);
    for @others -> $m {
      unless $m ~~ Matcher {
        die "Matcher.or requires Matcher arguments";
      }
    }
    ::('BDD::Behave::Matcher::OrMatcher').new(
      :matchers((self, |@others).flat.List),
    );
  }
}

class AndMatcher does Matcher is export {
  has @.matchers;
  has Int $.failing-index is rw;

  method matches($actual --> Bool) {
    $!failing-index = Int;
    for @!matchers.kv -> $i, $m {
      unless ?$m.matches($actual) {
        $!failing-index = $i;
        return False;
      }
    }
    True;
  }

  method failing-matcher() {
    return Nil unless $!failing-index.defined;
    @!matchers[$!failing-index];
  }

  method failure-message($actual --> Str) {
    my $desc = self.description;
    return "expected {$actual.raku} to {$desc}" unless $!failing-index.defined;
    my $failing = @!matchers[$!failing-index];
    my $inner = $failing.failure-message($actual);
    if $inner.defined {
      "expected {$actual.raku} to {$desc}, but {$failing.description} failed: $inner";
    } else {
      "expected {$actual.raku} to {$desc}, but {$failing.description} did not match";
    }
  }

  method failure-message-negated($actual --> Str) {
    "expected {$actual.raku} not to {self.description}";
  }

  method expected-value(--> Mu) {
    @!matchers.map(*.expected-value).List;
  }

  method description(--> Str) {
    @!matchers.map(*.description).join(' and ');
  }

  method and($other, *@rest) {
    my @others = ($other, |@rest);
    for @others -> $m {
      unless $m ~~ Matcher {
        die "Matcher.and requires Matcher arguments";
      }
    }
    AndMatcher.new(:matchers((|@!matchers, |@others).flat.List));
  }
}

class OrMatcher does Matcher is export {
  has @.matchers;
  has Int $.matched-index is rw;

  method matches($actual --> Bool) {
    $!matched-index = Int;
    for @!matchers.kv -> $i, $m {
      if ?$m.matches($actual) {
        $!matched-index = $i;
        return True;
      }
    }
    False;
  }

  method matched-matcher() {
    return Nil unless $!matched-index.defined;
    @!matchers[$!matched-index];
  }

  method failure-message($actual --> Str) {
    "expected {$actual.raku} to {self.description}, but none matched";
  }

  method failure-message-negated($actual --> Str) {
    my $desc = self.description;
    return "expected {$actual.raku} not to {$desc}" unless $!matched-index.defined;
    my $matched = @!matchers[$!matched-index];
    "expected {$actual.raku} not to {$desc}, but {$matched.description} matched";
  }

  method expected-value(--> Mu) {
    @!matchers.map(*.expected-value).List;
  }

  method description(--> Str) {
    @!matchers.map(*.description).join(' or ');
  }

  method or($other, *@rest) {
    my @others = ($other, |@rest);
    for @others -> $m {
      unless $m ~~ Matcher {
        die "Matcher.or requires Matcher arguments";
      }
    }
    OrMatcher.new(:matchers((|@!matchers, |@others).flat.List));
  }
}
