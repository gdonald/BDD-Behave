
use v6.d;
use MONKEY;

use Context;
use Describe;
use Expectation;
use It;
use Utils;

sub expect($given) {
  Expectation.new(:$given);
}

sub describe(Block $block) {
  Describe.new(:$block);
}

sub context(Block $block) {
  Context.new(:$block);
}

sub it(Block $block) {
  It.new(:$block);
}

class Behave {
  method run {
    for Utils.specs -> $spec {
      say $spec;

      my $content = $spec.IO.slurp.trim;

      EVAL $content;
    }
  }
}
