
use BDD::Behave::Colors;
use BDD::Behave::Diff;
use BDD::Behave::Failure;

class Failures is export {
  my @.list of Failure;

  method say {
    if Failures.list.elems {
      say red("Failures:") ~ "\n";
      for (Failures.list) -> $failure {
        my $location = $failure.file ~ ':' ~ $failure.line;
        if $failure.aggregation-label.defined {
          $location ~= " (aggregate: {$failure.aggregation-label})";
        }
        say '  [' ~ red(" ✗ ") ~ '] ' ~ $location;
        if $failure.message.defined {
          for $failure.message.lines -> $line {
            say "      $line";
          }
        } elsif $failure.given.defined || $failure.expected.defined {
          my $op = $failure.negated ?? "not to be" !! "to be";
          say "      Expected: " ~ $failure.given.raku;
          say "      $op: " ~ $failure.expected.raku;
          if !$failure.negated && diffable($failure.given, $failure.expected) {
            say "      Diff:";
            for render-diff($failure.given, $failure.expected).lines -> $line {
              say "        $line";
            }
          }
        }
      }
      say '';
    }
  }
}
