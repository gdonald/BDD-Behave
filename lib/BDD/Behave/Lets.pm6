
use MONKEY-SEE-NO-EVAL;

use BDD::Behave::Let;
use BDD::Behave::Klasses;

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
    my Str $scope-name = $name;
    my Str $call = Nil;

    if $name ~~ /^(\:\w+)\.(\w+)$/ {
      $scope-name = $0.Str;
      $call = $1.Str;
    }

    for Lets.scopes.reverse -> %scope {
      if %scope{$scope-name} {
        if $call {
          my $obj = %scope{$scope-name}.block()().Str ~ '.' ~ $call;
          if $obj ~~ /^(\w+)\./ {
            my $klass-name = $0.Str;
            my $klass = Klasses.get($klass-name);

            if $klass {
              try { EVAL $klass unless ::{$klass-name}:exists; }
              return EVAL $obj;
            }
          }
        }

        return %scope{$scope-name}.block()();
      }
    }
  }
}
