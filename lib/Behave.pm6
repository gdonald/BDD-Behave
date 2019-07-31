
use v6.d;
use MONKEY;

use BasicBlock;
use Colors;
use Expectation;
use Failures;
use Files;

class Behave {
  has @!args;
  has Bool $!verbose;

  submethod BUILD(:$!verbose, :@!args) {}

  method run {
    for Files.list(@!args) -> $file {
      Files.current = $file;
      say light-blue($file) ~ "\n";
      EVAL $file.IO.slurp; # TODO: handle files that match [\:\d+]?$
    }

    if Failures.list.elems {
      say red("Failures:") ~ "\n";
      for (Failures.list) -> $failure {
        say '  [' ~ red(" ✗ ") ~ '] ' ~ $failure.file ~ ':' ~ $failure.line;
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
