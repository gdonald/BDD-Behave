
unit class BDD::Behave::Lets;

use BDD::Behave::Let;

class Lets is export {
  my @.scopes;

  method push-scope() {
    Lets.scopes.push({});
  }

  method pop-scope() {
    Lets.scopes.pop();
  }

  method put(Str :$name, Block :$block) {
    Lets.push-scope if Lets.scopes.elems == 0;
    Lets.scopes[Lets.scopes.elems - 1]{$name} = Let.new(:$block);
  }

  method get(Str $name) {
    for Lets.scopes.reverse -> %scope {
      return %scope{$name}.block()() if %scope{$name};
    }
  }
}
