
use v6.d;
use MONKEY;

use Context;
use Describe;
use Expectation;
use Files;
use It;

class Behave {
  method run {
    for Files.list -> $file {
      say $file;
      EVAL $file.IO.slurp;
    }
  }
}

sub describe(Block $block) is export {
  Describe.new(:$block);
}

sub context(Block $block) is export {
  Context.new(:$block);
}

sub it(Block $block) is export {
  It.new(:$block);
}

sub expect($given) is export {
  Expectation.new(:$given);
}
