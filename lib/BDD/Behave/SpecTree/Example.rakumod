unit module BDD::Behave::SpecTree::Example;

need BDD::Behave::SpecTree::Core;
need BDD::Behave::LetRuntime;

constant SpecNode = BDD::Behave::SpecTree::Core::SpecNode;
constant LetRuntime = BDD::Behave::LetRuntime::LetRuntime;

class LetContext {
  method FALLBACK(Str $name, |c) {
    if c.elems == 0 {
      return $*LET-RUNTIME.value($name);
    }
    die "Let values are read-only";
  }
}

our class Example is SpecNode {
  has Callable $.block is required;
  has Bool $.pending is rw = False;

  method execute(*%context) {
    my @lets = self.get-metadata('lets', :default([])).flat.List;
    my $runtime = LetRuntime.new(:definitions(@lets));
    my $*LET-RUNTIME = $runtime;
    my $ctx = LetContext.new;

    my $sig = $!block.signature;
    if $sig.params.elems > 0 && !$sig.params[0].named {
      $!block($ctx, |%context);
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
