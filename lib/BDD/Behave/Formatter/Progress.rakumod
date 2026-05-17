use BDD::Behave::Colors;
use BDD::Behave::Failures;
use BDD::Behave::Formatter;
use BDD::Behave::Formatter::Tree;

unit class BDD::Behave::Formatter::Progress is BDD::Behave::Formatter::Tree;

has Bool $!multi-file = False;

method name(--> Str) { 'progress' }

method suite-loading(Str :$file) { }

method suite-start($suite, Bool :$multi-file = False) {
  $!multi-file = $multi-file;
}

method group-start($group) { }
method group-end($group)   { }
method group-around-skipped($group) {
  print light-blue('S');
}

method example-start($example, Bool :$auto = False) { }
method example-auto-description($example, Str :$description) { }

method example-pass($example) {
  print green('.');
}

method example-fail($example, :$failure-info) {
  print red('F');
}

method example-pending($example) {
  print light-blue('*');
}

method example-skipped($example) {
  print light-blue('S');
}

method example-around-skipped($example) {
  print light-blue('S');
}

method example-slow($example, Real :$threshold) { }
method example-memory-leak($example, Int :$threshold) { }

method run-summary(
  $result,
  Bool :$aborted   = False,
  Int  :$fail-fast = 0,
  Str  :$order     = 'defined',
  Int  :$seed,
) {
  return if $!multi-file;
  callsame;
}

method multi-file-overall(
  $result,
  Str :$order = 'defined',
  Int :$seed,
) {
  say '';
  Failures.say;
  callsame;
}
