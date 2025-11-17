unit module BDD::Behave::SpecTree::Example;

need BDD::Behave::SpecTree::Core;
need BDD::Behave::LetRuntime;

constant SpecNode = BDD::Behave::SpecTree::Core::SpecNode;
constant LetRuntime = BDD::Behave::LetRuntime::LetRuntime;

our class Example is SpecNode {
  has Callable $.block is required;
  has Bool $.pending is rw = False;

  method execute(*%context) {
    my @lets = self.get-metadata('lets', :default([])).flat.List;
    my $runtime = LetRuntime.new(:definitions(@lets));
    my $*LET-RUNTIME = $runtime;
    $!block(|%context);
  }

  method mark-pending(:$reason) {
    $!pending = True;
    self.set-metadata(:pending-reason($reason // 'pending'));
    self;
  }
}
