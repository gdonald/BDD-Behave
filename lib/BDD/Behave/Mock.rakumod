unit module BDD::Behave::Mock;

use BDD::Behave::Failure;
use BDD::Behave::Failures;

sub user-callframe() {
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

  method any-for(Mu $target is raw --> Bool) {
    for @active -> $s {
      return True if $s.target === $target;
    }
    False;
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
  has Call    @!calls;

  method calls() { @!calls.List }
  method calls-of(Str:D $m) { @!calls.grep({ .method eq $m }).List }
  method received(Str:D $m --> Bool) { @!calls.first({ .method eq $m }).defined }
  method call-count(Str:D $m --> Int) { +@!calls.grep({ .method eq $m }) }

  method record-call(|c) {
    my $caller = user-callframe();
    @!calls.push: Call.new(
      :method($!method-name),
      :args(c.list),
      :named(c.hash),
      :file($caller.defined ?? $caller.file.IO !! IO::Path),
      :line($caller.defined ?? $caller.line.Int !! 0),
    );
  }

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

      $stub.record-call(|c);

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

constant SPY-RESERVED-METHODS = set <
  BUILD BUILDALL DESTROY new clone perl raku gist Str
  defined DEFINITE WHAT WHO HOW WHICH WHERE so not Bool
  ACCEPTS dispatch:<.> dispatch:<.?> dispatch:<.+> dispatch:<.*>
>;

sub spy-method-candidates(Mu \cls) {
  my @names;
  my %seen;
  for cls.^methods(:local) -> $m {
    next unless $m ~~ Method;
    next if $m ~~ Submethod;
    my $name = try { $m.name };
    next unless $name.defined && $name ~~ Str;
    next if $name eq '' || $name.starts-with('!');
    next if $name (elem) SPY-RESERVED-METHODS;
    next if %seen{$name}++;
    @names.push($name);
  }
  @names;
}

our sub spy(|args) is export {
  my @pos   = args.list;
  my %named = args.hash;

  if @pos.elems == 0 && %named.elems == 0 {
    return Double.new(:double-name<spy>);
  }

  if @pos.elems == 1 && %named.elems == 0 {
    my \arg = @pos[0];
    if arg.defined && arg.DEFINITE && arg !~~ Str {
      my $cls = arg.WHAT;
      for spy-method-candidates($cls) -> $name {
        my $stub = Stub.new(:target(arg), :method-name($name));
        $stub.install;
        StubRegistry.register($stub);
        $stub.and-call-original;
      }
      return arg;
    }
  }

  double(|args);
}

class HaveReceivedExpectation is export {
  has Mu       $.target;
  has Str      $.method-name is required;
  has Bool     $.negated     = False;
  has Str      $.file        is required;
  has Int      $.line        is required;
  has Bool     $!has-with-filter = False;
  has @!with-args;
  has %!with-named;
  has Str      $!count-kind  = 'present';
  has Int      $!count-n     = 0;
  has          $!recorded-failure;

  submethod BUILD(Mu :$target is raw, :$!method-name, :$!negated, :$!file, :$!line) {
    $!target := $target;
  }

  method calls() {
    if $!target.WHAT === Double {
      return $!target.calls-of($!method-name);
    }

    my $stub = StubRegistry.find-existing($!target, $!method-name);
    return $stub.defined ?? $stub.calls-of($!method-name) !! ();
  }

  method has-recorder(--> Bool) {
    return True if $!target.WHAT === Double;
    StubRegistry.find-existing($!target, $!method-name).defined;
  }

  method match-call(Call $c --> Bool) {
    return True unless $!has-with-filter;
    return False unless @!with-args.elems == $c.args.elems;
    for @!with-args.kv -> $i, $expected {
      my $actual = $c.args[$i];
      if $expected ~~ ArgMatcher {
        return False unless $expected.matches($actual);
      } else {
        return False unless $actual ~~ $expected;
      }
    }
    for %!with-named.kv -> $k, $expected {
      return False unless $c.named{$k}:exists;
      my $actual = $c.named{$k};
      if $expected ~~ ArgMatcher {
        return False unless $expected.matches($actual);
      } else {
        return False unless $actual ~~ $expected;
      }
    }
    True;
  }

  method matching-calls() {
    self.calls.grep({ self.match-call($_) }).List;
  }

  method count-met(Int $count --> Bool) {
    given $!count-kind {
      when 'present'  { return $count > 0 }
      when 'exactly'  { return $count == $!count-n }
      when 'at-least' { return $count >= $!count-n }
      when 'at-most'  { return $count <= $!count-n }
    }
    False;
  }

  method count-clause(--> Str) {
    given $!count-kind {
      when 'present'  { 'at least once' }
      when 'exactly'  {
        $!count-n == 1 ?? 'exactly once'
        !! $!count-n == 2 ?? 'exactly twice'
        !! "exactly {$!count-n} times"
      }
      when 'at-least' {
        $!count-n == 1 ?? 'at least once'
        !! "at least {$!count-n} times"
      }
      when 'at-most'  {
        $!count-n == 1 ?? 'at most once'
        !! "at most {$!count-n} times"
      }
      default { 'at least once' }
    }
  }

  method args-clause(--> Str) {
    return '' unless $!has-with-filter;
    my @parts;
    for @!with-args -> $a {
      @parts.push: $a ~~ ArgMatcher ?? $a.describe !! $a.raku;
    }
    for %!with-named.kv -> $k, $v {
      my $val = $v ~~ ArgMatcher ?? $v.describe !! $v.raku;
      @parts.push: ":$k\($val)";
    }
    " with ({@parts.join(', ')})";
  }

  method target-description(--> Str) {
    if $!target.WHAT === Double {
      my $name = $!target.double-name;
      return "double($name.raku())#{$!method-name}";
    }
    my $owner = ($!target.defined && $!target.DEFINITE) ?? $!target.WHAT !! $!target;
    "{$owner.^name}#{$!method-name}";
  }

  method validate(--> Nil) {
    unless self.has-recorder {
      my $msg = "expect({self.target-description}).to.have-received(...): "
              ~ "no stub installed; call `allow($!target.^name())"
              ~ ".to.receive('{$!method-name}')` first or use `spy(\$obj)`";
      self.replace-failure($msg);
      return;
    }

    my @matches = self.matching-calls;
    my $count   = @matches.elems;
    my $met     = self.count-met($count);
    $met = !$met if $!negated;

    if $met {
      self.clear-failure;
      return;
    }

    my $verb = $!negated ?? 'not to have been called' !! 'to have been called';
    my $expected = self.count-clause ~ self.args-clause;
    my $actual-clause = self.actual-clause($count);

    my $msg = "expected {self.target-description} $verb $expected\n     got $actual-clause";
    self.replace-failure($msg);
  }

  method actual-clause(Int $observed --> Str) {
    my $total = self.calls.elems;
    if $!has-with-filter {
      return "$observed matching call{$observed == 1 ?? '' !! 's'} (out of $total total)";
    }
    "$total call{$total == 1 ?? '' !! 's'}";
  }

  method replace-failure(Str $msg --> Nil) {
    self.clear-failure;
    my $f = Failure.new(
      :$!file, :$!line, :message($msg), :negated($!negated),
    );
    Failures.list.push($f);
    $!recorded-failure = $f;
  }

  method clear-failure(--> Nil) {
    return unless $!recorded-failure.defined;
    my $list = Failures.list;
    my $idx  = $list.first({ $_ === $!recorded-failure }, :k);
    $list.splice($idx, 1) if $idx.defined;
    $!recorded-failure = Nil;
  }

  method with(*@a, *%n) {
    @!with-args = @a;
    %!with-named = %n;
    $!has-with-filter = True;
    self.validate;
    self;
  }

  method times(Int:D $n) {
    $!count-kind = 'exactly';
    $!count-n    = $n;
    self.validate;
    self;
  }

  method exactly(Int:D $n)  { self.times($n) }
  method once               { self.times(1) }
  method twice              { self.times(2) }
  method thrice             { self.times(3) }

  method at-least(Int:D $n) {
    $!count-kind = 'at-least';
    $!count-n    = $n;
    self.validate;
    self;
  }

  method at-most(Int:D $n) {
    $!count-kind = 'at-most';
    $!count-n    = $n;
    self.validate;
    self;
  }
}
