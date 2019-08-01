
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
      self.eval-file(:$file);
    }

    if Failures.list.elems {
      say red("Failures:") ~ "\n";
      for (Failures.list) -> $failure {
        say '  [' ~ red(" ✗ ") ~ '] ' ~ $failure.file ~ ':' ~ $failure.line;
      }
      say '';
    }
  }

  method eval-file(:$file) {
    if $file ~~ /\: \d+$/ {
      self.eval-partial-file(:$file);
    } else {
      EVAL $file.IO.slurp;
    }
  }

  method eval-partial-file(:$file) {
    my ($path, $line) = $file.split(':');
    say $path;
    say $line;
    EVAL $path.IO.slurp;
  }
}

class Context is BasicBlock {}
class Describe is BasicBlock {}
class It is BasicBlock {}

sub describe(Block $block) is export { Describe.new(:$block) }
sub context(Block $block) is export { Context.new(:$block) }
sub it(Block $block) is export { It.new(:$block) }
sub expect($given) is export { Expectation.new(:$given) }
