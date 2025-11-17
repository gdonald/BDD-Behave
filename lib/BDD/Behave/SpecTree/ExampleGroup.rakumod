unit module BDD::Behave::SpecTree::ExampleGroup;

need BDD::Behave::SpecTree::Core;
need BDD::Behave::SpecTree::Example;

constant SpecNode = BDD::Behave::SpecTree::Core::SpecNode;
constant Container = BDD::Behave::SpecTree::Core::Container;
constant HookPhase = BDD::Behave::SpecTree::Core::HookPhase;
constant Example = BDD::Behave::SpecTree::Example::Example;

our class ExampleGroup is SpecNode does Container {
  has Callable @.before-all;
  has Callable @.after-all;
  has Callable @.before-each;
  has Callable @.after-each;
  has @.lets;

  method groups {
    @!children.grep(::?CLASS);
  }

  method examples {
    @!children.grep(Example);
  }

  method add-group(::?CLASS:D $group --> ::?CLASS) {
    self.add-child($group);
  }

  method add-example(Example $example --> Example) {
    self.add-child($example);
  }

  method add-let($let) {
    @!lets.push($let);
    $let;
  }

  method let-definitions {
    @!lets // [];
  }

  method add-hook(HookPhase:D $phase, Callable:D $callback --> Callable) {
    given $phase {
      when 'before-all'  { @!before-all.push($callback) }
      when 'after-all'   { @!after-all.push($callback) }
      when 'before-each' { @!before-each.push($callback) }
      when 'after-each'  { @!after-each.push($callback) }
    }
    $callback;
  }

  method hooks(HookPhase:D $phase --> List) {
    given $phase {
      when 'before-all'  { @!before-all.List }
      when 'after-all'   { @!after-all.List }
      when 'before-each' { @!before-each.List }
      when 'after-each'  { @!after-each.List }
    }
  }
}
