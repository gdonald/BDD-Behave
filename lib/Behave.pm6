
use v6.d;
use MONKEY;

use BasicBlock;
use Expectation;
use Failure;
use Files;

class Behave {
  method run {
    for Files.list -> $file {
      set-current-file($file);
      say $file;
      EVAL $file.IO.slurp;
    }

    if get-failures.elems {
      say "Failures: \n";
      for (get-failures) -> $failure {
        say '  ' ~ $failure.file ~ ':' ~ $failure.line;
      }
      say '';
    }
  }
}

class Context is BasicBlock {}
class Describe is BasicBlock {}
class It is BasicBlock {}

sub describe(Block $block) is export { Describe.new(:$block) }
sub context(Block $block) is export { Context.new(:$block) }
sub it(Block $block) is export { It.new(:$block) }
sub expect($given) is export { Expectation.new(:$given) }
