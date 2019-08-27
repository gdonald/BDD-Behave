
unit class BDD::Behave::Klasses;

use BDD::Behave::Klass;

class Klasses is export {
  my %.entries;

  method put(Str :$name, Str :$def) {
    Klasses.entries{$name} = Klass.new(:$def);
  }

  method get(Str $name) {
    return Klasses.entries{$name}.def if Klasses.entries{$name};
  }
}
