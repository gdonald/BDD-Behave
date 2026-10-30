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
use BDD::Behave::Coverage;

sub note-loading(Str $name --> Nil) {
  return unless %*ENV<BEHAVE_LOAD_PROGRESS>;

  $*ERR.say(LOAD-PROGRESS-MARKER ~ $name);
  $*ERR.flush;
}

our sub load-spec-file($file) is export {
  my $path = $file ~~ IO::Path ?? $file !! $file.IO;
  LEAVE registry().finish-loading($path);

  note-loading(~$path);

  eval-spec-source($path.slurp, $path.absolute.Str);
}

our sub load-module(Str $module) is export {
  note-loading($module);

  require ::($module);
}

our sub provided-modules(IO::Path $meta-file --> List) is export {
  return () unless $meta-file.e;

  my %meta = BDD::Behave::Coverage::parse-baseline-json($meta-file.slurp);
  (%meta<provides> // {}).keys.sort.List;
}
