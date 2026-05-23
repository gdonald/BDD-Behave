unit module BDD::Behave::SpecLoader;

my Int $counter = 0;

# Unqualified, single-segment name so the wrapper is easy to look up via the
# SpecLoader's own stash regardless of where Raku attaches it lexically.
our sub next-iso-name(--> Str) {
  "BehaveSpecIso{++$counter}";
}

our sub wrap-source(Str:D $code, Str:D $iso-name --> Str) {
  "module $iso-name \{ {$code}\n}";
}

# Strip the wrapper prefix from every reachable type's .^name so failure
# messages, doubles, and exception types render the names the user wrote.
# Two spec files declaring `class Greeter { }` end up in distinct anonymous
# wrappers but each Greeter.^name reads as `'Greeter'`.
#
# Implementation: walk every stash reachable from GLOBAL and from the wrapper
# itself, and call `^set_name` on any type whose current name starts with the
# wrapper prefix. Cycle detection via $node.WHICH. Compound-name declarations
# like `class X::Y::Z { }` install nested packages in GLOBAL but keep the
# wrapper prefix on the leaf class's `.^name`, so we have to start from GLOBAL
# rather than only the wrapper.
our sub restore-short-names($wrapper-type --> Nil) {
  my $prefix = $wrapper-type.^name ~ '::';
  my %seen;
  walk-and-rename(GLOBAL, $prefix, %seen);
  walk-and-rename($wrapper-type, $prefix, %seen);
}

sub walk-and-rename($node, Str:D $prefix, %seen --> Nil) {
  my $id;
  try { $id = $node.WHICH.Str; CATCH { default { return } } }
  return unless $id.defined;
  return if %seen{$id}:exists;
  %seen{$id} = True;

  my $stash;
  try { $stash = $node.WHO; CATCH { default { return } } }
  return unless $stash.defined && $stash.keys.elems;

  for $stash.keys -> $key {
    next if $key.starts-with('&');
    next if $key.starts-with('$');
    next if $key.starts-with('@');
    next if $key.starts-with('%');
    my $val := $stash{$key};
    if $val.HOW.^can('set_name') {
      my $current = $val.^name;
      if $current.starts-with($prefix) {
        my $short = $current.substr($prefix.chars);
        $val.HOW.set_name($val, $short);
      }
    }
    walk-and-rename($val, $prefix, %seen);
  }
}

our sub find-wrapper(Str:D $iso-name) {
  my $loader-stash := ::('BDD::Behave::SpecLoader').WHO;
  if $loader-stash{$iso-name}:exists {
    return $loader-stash{$iso-name};
  }
  my $global-stash := GLOBAL.WHO;
  if $global-stash{$iso-name}:exists {
    return $global-stash{$iso-name};
  }
  Nil;
}

our sub load-spec-file($file) is export {
  use MONKEY-SEE-NO-EVAL;

  my $path     = $file ~~ IO::Path ?? $file !! $file.IO;
  my $code     = $path.slurp;
  my $iso-name = next-iso-name();
  my $wrapped  = wrap-source($code, $iso-name);

  EVAL $wrapped, :filename($path.absolute.Str);

  my $wrapper := find-wrapper($iso-name);
  restore-short-names($wrapper) if $wrapper !=:= Nil;
}
