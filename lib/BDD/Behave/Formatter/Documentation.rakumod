use BDD::Behave::Colors;
use BDD::Behave::Failures;
use BDD::Behave::Formatter;
use BDD::Behave::Formatter::Tree;

unit class BDD::Behave::Formatter::Documentation is BDD::Behave::Formatter::Tree;

has Int $!indent = 0;
has Bool $!multi-file = False;

method name(--> Str) { 'documentation' }

method !prefix(--> Str) {
  '  ' x $!indent;
}

method suite-loading(Str :$file) { }

method suite-start($suite, Bool :$multi-file = False) {
  $!multi-file = $multi-file;
  if $multi-file {
    say '';
    say $suite.file.basename;
  }
}

method group-start($group) {
  say self!prefix ~ $group.description;
  $!indent++;
}

method group-end($group) {
  $!indent--;
}

method group-around-skipped($group) {
  say self!prefix ~ light-blue('(group skipped: around-all did not invoke continuation)');
}

method example-start($example, Bool :$auto = False) { }
method example-auto-description($example, Str :$description) {
  say self!prefix ~ green($description);
}

method example-pass($example) {
  say self!prefix ~ green($example.description);
}

method example-fail($example, :$failure-info) {
  say self!prefix ~ red($example.description ~ ' (FAILED)');
}

method example-pending($example) {
  say self!prefix ~ light-blue($example.description ~ ' (PENDING)');
}

method example-skipped($example) {
  say self!prefix ~ light-blue($example.description ~ ' (SKIPPED)');
}

method example-around-skipped($example) {
  say self!prefix ~ light-blue($example.description ~ ' (SKIPPED: around-each did not invoke continuation)');
}

method example-slow($example, Real :$threshold) { }

method run-summary(
  $result,
  Bool :$aborted   = False,
  Int  :$fail-fast = 0,
  Str  :$order     = 'defined',
  Int  :$seed,
  Bool :$show-seed = False,
) {
  return if $!multi-file;
  callsame;
}

method multi-file-overall(
  $result,
  Str :$order = 'defined',
  Int :$seed,
  Bool :$show-seed = False,
) {
  say '';
  Failures.say;
  callsame;
}
