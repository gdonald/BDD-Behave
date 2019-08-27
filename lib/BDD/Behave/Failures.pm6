
unit class BDD::Behave::Failures;

use BDD::Behave::Colors;
use BDD::Behave::Failure;

class Failures is export {
  my @.list of Failure;

  method say {
    if Failures.list.elems {
      say red("Failures:") ~ "\n";
      for (Failures.list) -> $failure {
        say '  [' ~ red(" ✗ ") ~ '] ' ~ $failure.file ~ ':' ~ $failure.line;
      }
      say '';
    }
  }
}
