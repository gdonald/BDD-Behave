
use BDD::Behave::Indent;

class BasicBlock is export {
  our $block;

  submethod BUILD(:$block) {
    indent -> 'do' {
      my $desc = block-desc($block);
      say Indent.get ~ $desc;
      $block($desc);
    }
  }
}
