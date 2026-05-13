unit module BDD::Behave::Mock::Stub;

use BDD::Behave::Mock::ArgMatcher;
use BDD::Behave::Mock::Double;

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
    $!is-double = $target.WHAT === Double;
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
