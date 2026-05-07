unit module BDD::Behave::SpecTree;

need BDD::Behave::SpecTree::Core;
need BDD::Behave::SpecTree::Example;
need BDD::Behave::SpecTree::ExampleGroup;
need BDD::Behave::SpecTree::Suite;

constant HookPhase = BDD::Behave::SpecTree::Core::HookPhase;
constant SpecNode = BDD::Behave::SpecTree::Core::SpecNode;
constant Container = BDD::Behave::SpecTree::Core::Container;
constant Hook = BDD::Behave::SpecTree::Core::Hook;
constant Example = BDD::Behave::SpecTree::Example::Example;
constant ExampleGroup = BDD::Behave::SpecTree::ExampleGroup::ExampleGroup;
constant Suite = BDD::Behave::SpecTree::Suite::Suite;

sub base-exports() {
  %(
    HookPhase => HookPhase,
    SpecNode => SpecNode,
    Container => Container,
    Hook => Hook,
    Example => Example,
    ExampleGroup => ExampleGroup,
    Suite => Suite,
  );
}

sub EXPORT(:$ALL?) {
  my %exports = base-exports();
  %(
    DEFAULT => %exports,
    ALL => %exports,
  );
}
