unit module BDD::Behave::Mock;

class Call is export {
  has Str $.method is required;
  has @.args;
  has %.named;
  has IO::Path $.file;
  has Int $.line;
}

class StubRegistry is export {
  my @active;

  method register($stub) {
    @active.push($stub);
    $stub;
  }

  method find-existing(Mu $target is raw, Str:D $method-name) {
    for @active -> $s {
      next unless $s.method-name eq $method-name;
      next unless $s.target === $target;
      return $s;
    }
    Nil;
  }

  method remove($stub) {
    my $idx = @active.first({ $_ === $stub }, :k);
    return unless $idx.defined;
    @active.splice($idx, 1);
    try {
      $stub.uninstall;
      CATCH { default { warn "Failed to uninstall stub: {.message}" } }
    }
  }

  method clear-all {
    self.clear-since(0);
  }

  method clear-since(Int $snapshot) {
    while @active.elems > $snapshot {
      my $stub = @active.pop;
      try {
        $stub.uninstall;
        CATCH { default { warn "Failed to uninstall stub: {.message}" } }
      }
    }
  }

  method active-count(--> Int) { +@active }
}

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

  method !user-callframe() {
    my $i = 1;
    loop {
      my $cf = callframe($i++);
      last without $cf;
      last if $i > 32;
      my $file = ~($cf.file // '');
      next if $file eq '' || $file.contains('Metamodel') || $file.contains('NQP::')
              || $file.contains('/nqp') || $file.contains('Mock.rakumod');
      return $cf;
    }
    Nil;
  }

  method FALLBACK(Str $name, |c) {
    if $!double-class !=== Mu && !$!double-class.^can($name) {
      die "Double for '{$!double-name}': "
          ~ "{$!double-class.^name} has no method '$name'";
    }

    my $caller = self!user-callframe;
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

class Stub is export {
  has Mu      $.target;
  has Bool    $.target-defined;
  has Str     $.method-name is required;
  has Mu      $!routine;
  has         $!handle;
  has Bool    $!installed = False;
  has Str     $.mode = 'return';
  has Mu      $.return-value = Any;
  has Mu      $.exception;
  has Mu      $.callable-stub;
  has Bool    $.is-double = False;
  has Bool    $!stub-set = False;
  has Mu      $.previous-double-stub;
  has Bool    $.had-previous-double-stub = False;

  submethod BUILD(Mu :$target is raw, :$!method-name) {
    $!target := $target;
    $!target-defined = $target.defined && $target.DEFINITE;
    $!is-double = $target.WHAT === BDD::Behave::Mock::Double;
  }

  method and-return(Mu $value is raw) {
    $!return-value := $value;
    $!mode = 'return';
    $!stub-set = True;
    self.refresh-double-stub if $!is-double;
    self;
  }

  method and-raise(Mu $exception is raw) {
    $!exception := $exception;
    $!mode = 'raise';
    $!stub-set = True;
    self.refresh-double-stub if $!is-double;
    self;
  }

  method and-call-original {
    if $!is-double {
      die "and-call-original is not supported on a Double — there is no original method";
    }
    $!mode = 'call-original';
    $!stub-set = True;
    self;
  }

  method and-do(&callable) {
    $!callable-stub = &callable;
    $!mode = 'callable';
    $!stub-set = True;
    self.refresh-double-stub if $!is-double;
    self;
  }

  method install {
    return if $!installed;

    if $!is-double {
      $!had-previous-double-stub = $!target.stubs{$!method-name}:exists;
      $!previous-double-stub = $!target.stubs{$!method-name} if $!had-previous-double-stub;
      self.refresh-double-stub;
      $!installed = True;
      return self;
    }

    my $owner = $!target-defined ?? $!target.WHAT !! $!target;
    my &meth = $owner.^find_method($!method-name);

    unless &meth.defined {
      die "allow(): cannot stub '{$!method-name}' on {$owner.^name}; "
          ~ "no such method";
    }

    $!routine := &meth;

    my $stub = self;
    $!handle = &meth.wrap(method (|c) {
      if $stub.target-defined && self !=== $stub.target {
        return callsame;
      }

      given $stub.mode {
        when 'raise'         { die $stub.exception }
        when 'callable'      { return $stub.callable-stub.(|c) }
        when 'call-original' { return callsame }
        default              { return $stub.return-value }
      }
    });
    $!installed = True;
    self;
  }

  method refresh-double-stub {
    return unless $!is-double;
    my %stubs := $!target.raw-stubs;
    given $!mode {
      when 'raise' {
        my $ex := $!exception;
        %stubs{$!method-name} = sub (|c) { die $ex };
      }
      when 'callable' {
        %stubs{$!method-name} = $!callable-stub;
      }
      default {
        %stubs{$!method-name} = $!return-value;
      }
    }
  }

  method uninstall {
    return unless $!installed;

    if $!is-double {
      my %stubs := $!target.raw-stubs;
      if $!had-previous-double-stub {
        %stubs{$!method-name} = $!previous-double-stub;
      } else {
        %stubs{$!method-name}:delete;
      }
      $!installed = False;
      return self;
    }

    if $!routine.defined && $!handle.defined {
      try {
        $!routine.unwrap($!handle);
        CATCH { default { warn "Stub unwrap failed: {.message}" } }
      }
    }
    $!installed = False;
    self;
  }
}

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

    if $target.WHAT === BDD::Behave::Mock::Double {
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
