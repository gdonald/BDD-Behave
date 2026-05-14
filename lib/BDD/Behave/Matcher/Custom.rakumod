unit module BDD::Behave::Matcher::Custom;

use BDD::Behave::Matcher;

class DefinedMatcher does Matcher is export {
  has Str  $.name;
  has List $.args   = ();
  has Map  $.kwargs = Map.new;
  has      &.match-block is required;
  has      &.failure-message-block;
  has      &.failure-message-negated-block;
  has      &.description-block;
  has      &.expected-value-block;

  method !invoke(&block, *@extra) {
    if $!kwargs.elems {
      block(|@extra, |$!args, |$!kwargs);
    } else {
      block(|@extra, |$!args);
    }
  }

  method matches($actual --> Bool) {
    ?self!invoke(&!match-block, $actual);
  }

  method failure-message($actual --> Str) {
    return Str unless &!failure-message-block.defined;
    self!invoke(&!failure-message-block, $actual).Str;
  }

  method failure-message-negated($actual --> Str) {
    return Str unless &!failure-message-negated-block.defined;
    self!invoke(&!failure-message-negated-block, $actual).Str;
  }

  method expected-value(--> Mu) {
    if &!expected-value-block.defined {
      return self!invoke(&!expected-value-block);
    }
    return $!args[0] if $!args.elems == 1 && !$!kwargs.elems;
    return $!kwargs  if !$!args.elems && $!kwargs.elems;
    $!args;
  }

  method description(--> Str) {
    if &!description-block.defined {
      return self!invoke(&!description-block).Str;
    }
    $!name;
  }
}

class CustomMatcherRegistry {
  has %.matchers;

  method register(Str:D $name, %config --> Nil) {
    %config<match>:exists
      or die "define-matcher '$name': match block is required";
    %!matchers{$name} = %config;
  }

  method exists(Str:D $name --> Bool) {
    %!matchers{$name}:exists;
  }

  method lookup(Str:D $name) {
    %!matchers{$name}:exists
      or die "Unknown custom matcher: '$name'";
    %!matchers{$name};
  }

  method names() {
    %!matchers.keys.sort.List;
  }

  method clear() {
    %!matchers = ();
  }

  method build(Str:D $name, |c) {
    my %config = self.lookup($name);
    my $args   = c.list.List;
    my $kwargs = c.hash.Map;
    my %builder;
    %builder<name>                          = $name;
    %builder<args>                          = $args;
    %builder<kwargs>                        = $kwargs;
    %builder<match-block>                   = %config<match>;
    %builder<failure-message-block>         = %config<failure-message>         if %config<failure-message>:exists;
    %builder<failure-message-negated-block> = %config<failure-message-negated> if %config<failure-message-negated>:exists;
    %builder<description-block>             = %config<description>             if %config<description>:exists;
    %builder<expected-value-block>          = %config<expected-value>          if %config<expected-value>:exists;
    DefinedMatcher.new(|%builder);
  }
}

my CustomMatcherRegistry $REGISTRY .= new;

our sub registry() {
  $REGISTRY;
}

our sub define-matcher(Str:D $name, *%blocks) {
  %blocks<match>:exists
    or die "define-matcher '$name': match block is required";

  for %blocks.keys -> $key {
    next if $key (elem) set <match failure-message failure-message-negated description expected-value>;
    die "define-matcher '$name': unknown option ':$key' (allowed: match, failure-message, failure-message-negated, description, expected-value)";
  }

  for %blocks.kv -> $key, $value {
    unless $value ~~ Callable {
      die "define-matcher '$name': ':$key' must be a Callable";
    }
  }

  $REGISTRY.register($name, %blocks);

  sub (|c) {
    $REGISTRY.build($name, |c);
  };
}

our sub matcher(Str:D $name, |c) {
  $REGISTRY.build($name, |c);
}
