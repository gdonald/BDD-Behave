
use Indent;

class BasicBlock {
  our $block;

  submethod BUILD(:$block) {
    Indent.increase;
    my $this = $block.signature.params.first.constraint_list.first;
    say Indent.get ~ "$this";
    $block($this);
    Indent.decrease;
  }
}
