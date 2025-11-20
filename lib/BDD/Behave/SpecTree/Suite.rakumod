unit module BDD::Behave::SpecTree::Suite;

need BDD::Behave::SpecTree::Core;
need BDD::Behave::SpecTree::Example;
need BDD::Behave::SpecTree::ExampleGroup;

constant SpecNode = BDD::Behave::SpecTree::Core::SpecNode;
constant Container = BDD::Behave::SpecTree::Core::Container;
constant Example = BDD::Behave::SpecTree::Example::Example;
constant ExampleGroup = BDD::Behave::SpecTree::ExampleGroup::ExampleGroup;

our class Suite is SpecNode does Container {
  has @.lets;

  method groups {
    @!children.grep(ExampleGroup);
  }

  method examples {
    @!children.grep(Example);
  }

  multi method create(
    :$description = 'suite',
    :$file = $*PROGRAM.abspath.IO,
    :$line = 0,
    :%metadata = {}
  ) {
    self.new(:$description, :$file, :$line, :%metadata);
  }

  method add-group(ExampleGroup $group --> ExampleGroup) {
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
}
