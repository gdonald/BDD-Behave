use BDD::Behave::Formatter;
use BDD::Behave::Formatter::Documentation;
use BDD::Behave::Formatter::HTML;
use BDD::Behave::Formatter::JSON;
use BDD::Behave::Formatter::JsonEvents;
use BDD::Behave::Formatter::JUnit;
use BDD::Behave::Formatter::Progress;
use BDD::Behave::Formatter::TAP;
use BDD::Behave::Formatter::Tree;

class BDD::Behave::Formatter::Registry {
  my %registry;

  method register(Str $name, $class) {
    die "Formatter '$name' has already been registered"
      if %registry{$name}:exists;
    die "Formatter class for '$name' must compose BDD::Behave::Formatter"
      unless $class.^does(BDD::Behave::Formatter);
    %registry{$name} = $class;
  }

  method registered(Str $name --> Bool) {
    %registry{$name}:exists;
  }

  method names(--> List) {
    %registry.keys.sort.List;
  }

  method lookup(Str $name) {
    die "Unknown formatter: '$name' (available: {self.names.join(', ')})"
      unless %registry{$name}:exists;
    %registry{$name};
  }

  method create(Str $name, *%args) {
    my $class = self.lookup($name);
    $class.new(|%args);
  }

  method reset {
    %registry = ();
    self.register('documentation', BDD::Behave::Formatter::Documentation);
    self.register('html',          BDD::Behave::Formatter::HTML);
    self.register('json',          BDD::Behave::Formatter::JSON);
    self.register('json-events',   BDD::Behave::Formatter::JsonEvents);
    self.register('junit',         BDD::Behave::Formatter::JUnit);
    self.register('progress',      BDD::Behave::Formatter::Progress);
    self.register('tap',           BDD::Behave::Formatter::TAP);
    self.register('tree',          BDD::Behave::Formatter::Tree);
  }
}

BDD::Behave::Formatter::Registry.register('documentation', BDD::Behave::Formatter::Documentation);
BDD::Behave::Formatter::Registry.register('html',          BDD::Behave::Formatter::HTML);
BDD::Behave::Formatter::Registry.register('json',          BDD::Behave::Formatter::JSON);
BDD::Behave::Formatter::Registry.register('json-events',   BDD::Behave::Formatter::JsonEvents);
BDD::Behave::Formatter::Registry.register('junit',         BDD::Behave::Formatter::JUnit);
BDD::Behave::Formatter::Registry.register('progress',      BDD::Behave::Formatter::Progress);
BDD::Behave::Formatter::Registry.register('tap',           BDD::Behave::Formatter::TAP);
BDD::Behave::Formatter::Registry.register('tree',          BDD::Behave::Formatter::Tree);
