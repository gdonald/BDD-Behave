
unit module BDD::Behave;

use MONKEY;

use BDD::Behave::Actions;
use BDD::Behave::BasicBlock;
use BDD::Behave::Colors;
use BDD::Behave::Expectation;
use BDD::Behave::Failures;
use BDD::Behave::Files;
use BDD::Behave::Grammar;
use BDD::Behave::Let;

class Behave is export {
  has @!args;
  has Bool $!verbose;

  submethod BUILD(:$!verbose, :@!args) {
    self.run
  }

  method run {
    for Files.list(@!args) -> $file {
      Files.current = $file;
      say "\n" ~ light-blue($file);
      self.eval-file(:$file);
    }

    say '';
    Failures.say;
  }

  method eval-file(:$file) {
    if $file ~~ /\: \d+$/ {
      self.eval-partial-file(:$file);
    } else {
      # EVAL $file.IO.slurp;
      Grammar.parse($file.IO.slurp.trim, :actions(Actions));
    }
  }

  method eval-partial-file(:$file) {
    my ($path, $line) = $file.split(':');
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
sub let($name) is export { Let.new(:$name) }
