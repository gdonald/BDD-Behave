unit module BDD::Behave::Mock::ArgMatcher;

our sub user-callframe() is export {
  my $i = 1;
  loop {
    my $cf = callframe($i++);
    last without $cf;
    last if $i > 32;
    my $file = ~($cf.file // '');
    next if $file eq ''
            || $file.contains('Metamodel')
            || $file.contains('NQP::')
            || $file.contains('/nqp')
            || $file.contains('BDD/Behave/Mock');
    return $cf;
  }
  Nil;
}

class Call is export {
  has Str $.method is required;
  has @.args;
  has %.named;
  has IO::Path $.file;
  has Int $.line;
}

role ArgMatcher is export {
  method matches(Mu \value --> Bool) { ... }
  method describe(--> Str) { ... }
}

class AnyArg does ArgMatcher is export {
  method matches(Mu \value --> Bool) { True }
  method describe(--> Str) { 'anything' }
}

class InstanceOf does ArgMatcher is export {
  has Mu $.type;
  submethod BUILD(Mu :$type is raw) { $!type := $type }
  method matches(Mu \value --> Bool) { value ~~ $!type }
  method describe(--> Str) { "instance-of({$!type.^name})" }
}

class HashIncluding does ArgMatcher is export {
  has %.expected;
  submethod BUILD(:%expected) { %!expected = %expected }
  method matches(Mu \value --> Bool) {
    return False unless value ~~ Associative;
    for %!expected.kv -> $k, $exp {
      return False unless value{$k}:exists;
      my $actual = value{$k};
      if $exp ~~ ArgMatcher {
        return False unless $exp.matches($actual);
      } else {
        return False unless $actual ~~ $exp;
      }
    }
    True;
  }
  method describe(--> Str) { "hash-including({%!expected.raku})" }
}

class ArrayIncluding does ArgMatcher is export {
  has @.items;
  submethod BUILD(:@items) { @!items = @items }
  method matches(Mu \value --> Bool) {
    return False unless value ~~ Positional;
    my @actual = value.list;
    for @!items -> $exp {
      my $found;
      if $exp ~~ ArgMatcher {
        $found = @actual.first({ $exp.matches($_) }).defined;
      } else {
        $found = @actual.first({ $_ ~~ $exp }).defined;
      }
      return False unless $found;
    }
    True;
  }
  method describe(--> Str) { "array-including({@!items.raku})" }
}

our sub anything()                 is export { AnyArg.new }
our sub instance-of(Mu \type)      is export { InstanceOf.new(:type(type)) }
our sub hash-including(*%pairs)    is export { HashIncluding.new(:expected(%pairs)) }
our sub array-including(*@items)   is export { ArrayIncluding.new(:items(@items)) }
