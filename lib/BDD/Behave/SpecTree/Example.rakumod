unit module BDD::Behave::SpecTree::Example;

need BDD::Behave::SpecTree::Core;
need BDD::Behave::LetRuntime;

constant SpecNode = BDD::Behave::SpecTree::Core::SpecNode;
constant LetRuntime = BDD::Behave::LetRuntime::LetRuntime;

class LetContext {
  method FALLBACK(Str $name, |c) {
    my $runtime = $*LET-RUNTIME;

    if c.elems == 0 && $runtime.defined && $runtime.has-name($name) {
      return $runtime.value($name);
    }

    my $helpers = $*BEHAVE-HELPERS;

    if $helpers.defined {
      for $helpers.values -> $helper {
        return $helper."$name"(|c) if $helper.^can($name);
      }
    }

    if c.elems == 0 {
      return $runtime.value($name);
    }

    die "Let values are read-only";
  }
}

our class Example is SpecNode {
  has Callable $.block is required;
  has Bool $.pending is rw = False;
  has Real $.duration is rw;
  has Instant $.started-at is rw;
  has Instant $.finished-at is rw;
  has @.benchmarks;
  has Bool $!takes-context;

  method execute(*%context) {
    my $*BEHAVE-CURRENT-EXAMPLE = self;
    my $*BEHAVE-BENCHMARK-COUNTER = 0;

    my $existing;
    try { $existing = $*LET-RUNTIME if $*LET-RUNTIME.defined }

    if $existing.defined {
      self!run-block(|%context);
    } else {
      my @lets = self.get-metadata('lets', :default([])).flat.List;
      my $runtime = LetRuntime.new(:definitions(@lets));
      my $*LET-RUNTIME = $runtime;
      self!run-block(|%context);
    }
  }

  # The answer cannot change for a given block, and the block runs again for
  # every `--retry` attempt and every benchmark iteration.
  method !takes-context(--> Bool) {
    return $!takes-context if $!takes-context.defined;

    my $params = $!block.signature.params;

    $!takes-context = $params.elems > 0 && !$params[0].named;
  }

  method !run-block(*%context) {
    if self!takes-context {
      $!block(LetContext.new, |%context);
    } else {
      $!block(|%context);
    }
  }

  method mark-pending(:$reason) {
    $!pending = True;
    self.set-metadata(:pending-reason($reason // 'pending'));
    self;
  }
}
