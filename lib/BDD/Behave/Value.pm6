
unit class BDD::Behave::Value;

use BDD::Behave::Lets;

class Value is export {
  has Str $!raw;
  has Bool $!evaluated = False;
  has $!value = Nil;

  submethod BUILD(:$!raw) {}

  method get() {
    return $!value if $!evaluated;
    $!value = self.evaluate();
  }

  method evaluate() {
    $!evaluated = True;
    given $!raw {
      when .Str ~~ /^\:/ { Lets.get(.Str) }
      when .Numeric.so { +(.Str) }
      when .WHAT ~~ Match { .Str }
      when /^\'\d+\'$/ { $0 }
      default { dd $_; die "Unknown \$!raw ☹" }
    }
  }
}
