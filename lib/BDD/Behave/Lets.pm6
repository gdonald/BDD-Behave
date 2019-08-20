
unit class BDD::Behave::Lets;

use BDD::Behave::Let;

class Lets is export {
  my @.scopes = Array[Hash].new({});

  method push-scope() {
    Lets.scopes.push({});
  }

  method pop-scope() {
    Lets.scopes.pop();
  }

  method put(Str :$name, Block :$block) {
    Lets.scopes[Lets.scopes.elems]{$name} = Let.new(:$block);
  }

  method get(Str $name) {
    for Lets.scopes.reverse -> %scope {
      return %scope{$name}.block()() if %scope{$name};
    }
  }
}
