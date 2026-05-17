use BDD::Behave::Formatter;
use BDD::Behave::Formatter::Default;

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
    self.register('default', BDD::Behave::Formatter::Default);
  }
}

BDD::Behave::Formatter::Registry.register('default', BDD::Behave::Formatter::Default);
