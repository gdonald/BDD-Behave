
use BDD::Behave::Colors;
use BDD::Behave::Failure;

class Failures is export {
  my @.list of Failure;

  method say {
    if Failures.list.elems {
      say red("Failures:") ~ "\n";
      for (Failures.list) -> $failure {
        say '  [' ~ red(" ✗ ") ~ '] ' ~ $failure.file ~ ':' ~ $failure.line;
        if $failure.given.defined || $failure.expected.defined {
          my $op = $failure.negated ?? "not to be" !! "to be";
          say "      Expected: " ~ $failure.given.raku;
          say "      $op: " ~ $failure.expected.raku;
        }
      }
      say '';
    }
  }
}
