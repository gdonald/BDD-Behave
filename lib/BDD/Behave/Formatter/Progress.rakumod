use BDD::Behave::Colors;
use BDD::Behave::Failures;
use BDD::Behave::Formatter;
use BDD::Behave::Formatter::Tree;

unit class BDD::Behave::Formatter::Progress is BDD::Behave::Formatter::Tree;

has Bool $!multi-file = False;
has Int  $!total      = 0;
has Int  $!shown      = 0;

method name(--> Str) { 'progress' }

method set-total(Int $total) {
  $!total = $total;
}

method !maybe-print-total {
  return unless $!total > 0;
  $!shown++;
  print " ({$!shown}/{$!total})\n";
}

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
  self!maybe-print-total;
}

method example-fail($example, :$failure-info) {
  print red('F');
  self!maybe-print-total;
}

method example-pending($example) {
  print light-blue('*');
  self!maybe-print-total;
}

method example-skipped($example) {
  print light-blue('S');
  self!maybe-print-total;
}

method example-around-skipped($example) {
  print light-blue('S');
  self!maybe-print-total;
}

method example-retry($example, Int :$attempt, Int :$max-attempts) {
  print yellow('R');
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
