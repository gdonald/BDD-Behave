unit module BDD::Behave::SpecTree::ExampleGroup;

need BDD::Behave::SpecTree::Core;
need BDD::Behave::SpecTree::Example;

constant SpecNode = BDD::Behave::SpecTree::Core::SpecNode;
constant Container = BDD::Behave::SpecTree::Core::Container;
constant HookPhase = BDD::Behave::SpecTree::Core::HookPhase;
constant Hook = BDD::Behave::SpecTree::Core::Hook;
constant Example = BDD::Behave::SpecTree::Example::Example;

our class ExampleGroup is SpecNode does Container {
  has Hook @.before-all-hooks;
  has Hook @.after-all-hooks;
  has Hook @.before-each-hooks;
  has Hook @.after-each-hooks;
  has Hook @.around-all-hooks;
  has Hook @.around-each-hooks;
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

  method add-hook(HookPhase:D $phase, Callable:D $callback,
                  :@include-tags = [], :@exclude-tags = [], :%meta = %()
                  --> Hook) {
    my $hook = Hook.new(
      :$callback,
      :include-tags(@include-tags.list),
      :exclude-tags(@exclude-tags.list),
      :%meta,
    );
    given $phase {
      when 'before-all'  { @!before-all-hooks.push($hook) }
      when 'after-all'   { @!after-all-hooks.push($hook) }
      when 'before-each' { @!before-each-hooks.push($hook) }
      when 'after-each'  { @!after-each-hooks.push($hook) }
      when 'around-all'  { @!around-all-hooks.push($hook) }
      when 'around-each' { @!around-each-hooks.push($hook) }
    }
    $hook;
  }

  method hooks(HookPhase:D $phase --> List) {
    given $phase {
      when 'before-all'  { @!before-all-hooks.List }
      when 'after-all'   { @!after-all-hooks.List }
      when 'before-each' { @!before-each-hooks.List }
      when 'after-each'  { @!after-each-hooks.List }
      when 'around-all'  { @!around-all-hooks.List }
      when 'around-each' { @!around-each-hooks.List }
    }
  }
}
