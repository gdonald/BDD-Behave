unit module BDD::Behave::SpecTree::Example;

need BDD::Behave::SpecTree::Core;

constant SpecNode = BDD::Behave::SpecTree::Core::SpecNode;

our class Example is SpecNode {
  has Callable $.block is required;
  has Bool $.pending is rw = False;

  method execute(*%context) {
    $!block(|%context);
  }

  method mark-pending(:$reason) {
    $!pending = True;
    self.set-metadata(:pending-reason($reason // 'pending'));
    self;
  }
}
