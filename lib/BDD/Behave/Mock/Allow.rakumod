unit module BDD::Behave::Mock::Allow;

use BDD::Behave::Mock::Double;
use BDD::Behave::Mock::Stub;

class ReceiveSetup is export {
  has Stub $.stub is required;

  method and-return(Mu $value is raw) {
    $!stub.and-return($value);
    self;
  }

  method and-raise(Mu $exception is raw) {
    $!stub.and-raise($exception);
    self;
  }

  method and-call-original {
    $!stub.and-call-original;
    self;
  }

  method and-do(&callable) {
    $!stub.and-do(&callable);
    self;
  }
}

class AllowBuilder is export {
  has Mu $.target;

  submethod BUILD(Mu :$target is raw) { $!target := $target }

  method to { self }

  method receive(Str:D $method-name) {
    self.validate($method-name);
    if my $existing = StubRegistry.find-existing($!target, $method-name) {
      StubRegistry.remove($existing);
    }
    my $stub = Stub.new(:target($!target), :$method-name);
    $stub.install;
    StubRegistry.register($stub);
    ReceiveSetup.new(:$stub);
  }

  method validate(Str:D $method-name) {
    my $target := $!target;

    if $target.WHAT === Double {
      my $cls := $target.double-class;
      if $cls !=== Mu {
        unless $cls.^can($method-name) {
          die "allow(): {$cls.^name} has no method '$method-name'";
        }
      }
      return;
    }

    my $owner = ($target.defined && $target.DEFINITE) ?? $target.WHAT !! $target;
    unless $owner.^can($method-name) {
      die "allow(): {$owner.^name} has no method '$method-name'";
    }
  }
}

our sub allow(Mu \target) is export {
  AllowBuilder.new(:target(target));
}

our sub allow-any-instance-of(Mu \cls) is export {
  if cls.defined && cls.DEFINITE {
    die "allow-any-instance-of(): expected a type object (class), got an instance of {cls.^name}";
  }
  AllowBuilder.new(:target(cls));
}
