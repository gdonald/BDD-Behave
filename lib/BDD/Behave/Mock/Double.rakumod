unit module BDD::Behave::Mock::Double;

use BDD::Behave::Mock::ArgMatcher;

class Double is export {
  has Str $.double-name;
  has Mu   $.double-class;
  has %!stubs;
  has Call @!calls;

  submethod BUILD(:$!double-name, Mu :$double-class is raw = Mu, :%stubs) {
    $!double-class := $double-class;
    %!stubs = %stubs;
  }

  method add-stub(*%pairs) {
    if $!double-class !=== Mu {
      for %pairs.keys -> $name {
        unless $!double-class.^can($name) {
          die "Double for '{$!double-name}': cannot stub '$name'; "
              ~ "{$!double-class.^name} has no such method";
        }
      }
    }
    for %pairs.kv -> $name, $value {
      %!stubs{$name} = $value;
    }
    self;
  }

  method stubs() { %!stubs.clone }

  method raw-stubs() is rw { %!stubs }

  method calls() { @!calls.List }

  method calls-of(Str:D $method) {
    @!calls.grep({ .method eq $method }).List;
  }

  method received(Str:D $method --> Bool) {
    @!calls.first({ .method eq $method }).defined;
  }

  method call-count(Str:D $method --> Int) {
    +@!calls.grep({ .method eq $method });
  }

  method reset() {
    @!calls = ();
    self;
  }

  method FALLBACK(Str $name, |c) {
    if $!double-class !=== Mu && !$!double-class.^can($name) {
      die "Double for '{$!double-name}': "
          ~ "{$!double-class.^name} has no method '$name'";
    }

    my $caller = user-callframe();
    @!calls.push: Call.new(
      :method($name),
      :args(c.list),
      :named(c.hash),
      :file($caller.defined ?? $caller.file.IO !! IO::Path),
      :line($caller.defined ?? $caller.line.Int !! 0),
    );

    return %!stubs{$name} unless %!stubs{$name} ~~ Callable;
    %!stubs{$name}(|c);
  }
}

our sub double(|args) is export {
  my @pos   = args.list;
  my %named = args.hash;

  my Str $double-name;
  my Mu  $double-class = Mu;

  if @pos.elems == 0 {
    $double-name = 'anonymous';
  } elsif @pos.elems == 1 {
    if @pos[0] ~~ Str {
      $double-name = @pos[0];
    } else {
      $double-class = @pos[0];
      $double-name  = $double-class.^name;
    }
  } else {
    die "double() takes at most one positional argument (a name string or a class)";
  }

  if $double-class !=== Mu {
    for %named.keys -> $name {
      unless $double-class.^can($name) {
        die "Double for '$double-name': cannot stub '$name'; "
            ~ "{$double-class.^name} has no such method";
      }
    }
  }

  Double.new(:$double-name, :$double-class, :stubs(%named));
}
