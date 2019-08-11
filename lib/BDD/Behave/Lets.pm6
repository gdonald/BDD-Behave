
unit class BDD::Behave::Lets;

use BDD::Behave::Let;

class Lets is export {
  has @!scopes = {}, ;

  method push-scope() {
    @!scopes.push({});
  }

  method pop-scope() {
    @!scopes.pop();
  }

  method put(Str :$name, Block :$block) {
    @!scopes[*-1]{$name} = Let.new(:$block);
  }

  method get(Str $name) {
    for @!scopes.reverse -> %scope {
      return %scope{$name}.block()() if %scope{$name};
    }
  }
}
