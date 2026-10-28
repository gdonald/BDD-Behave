unit module BDD::Behave::Callsite;

# Run from a checkout, a frame's file is the path under lib/BDD/Behave. Run
# from an installed distribution, it is `site#sources/<sha1> (BDD::Behave::DSL)`.
our sub is-behave-source($file --> Bool) is export {
  my $name = ($file // '').Str;

  so $name.contains('BDD/Behave')
     || $name ~~ / '(BDD::Behave' [ '::' <-[)]>+ ]? ')' $ /;
}

our sub user-frame() is export {
  my $depth = 1;
  my $frame = callframe($depth);

  while $frame.defined && is-behave-source($frame.file) {
    $frame = callframe(++$depth);
  }

  $frame;
}
