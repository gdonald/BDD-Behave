
use Context;
use Describe;
use Expectation;
use It;

class Utils {

  method specs {
    my @files = Array.new;
    my @dir = 'specs'.IO;
    while @dir {
      for @dir.pop.dir -> $path {
        @files.push($path.Str);
      }
    }
    @files;
  }
}

sub expect($given) is export {
  Expectation.new(:$given);
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
