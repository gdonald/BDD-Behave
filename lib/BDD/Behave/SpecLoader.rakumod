# Top-level sub (outside `unit module`) so EVAL's $?PACKAGE is GLOBAL.
# A spec's `my class Foo { }` then renders as `Foo.^name eq 'Foo'`, not
# `'BDD::Behave::SpecLoader::Foo'`.
sub eval-spec-source(Str $code, Str $filename) {
  use MONKEY-SEE-NO-EVAL;
  EVAL $code, :$filename;
}

unit module BDD::Behave::SpecLoader;

use BDD::Behave::SpecRegistry;
use BDD::Behave::LoadProgress;

our sub load-spec-file($file) is export {
  my $path = $file ~~ IO::Path ?? $file !! $file.IO;
  LEAVE registry().finish-loading($path);

  if %*ENV<BEHAVE_LOAD_PROGRESS> {
    $*ERR.say(LOAD-PROGRESS-MARKER ~ $path);
    $*ERR.flush;
  }

  eval-spec-source($path.slurp, $path.absolute.Str);
}
