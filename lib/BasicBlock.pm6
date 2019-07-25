
use Indent;

class BasicBlock {
  our $block;

  submethod BUILD(:$block) {
    do-indent;
    my $this = $block.signature.params.first.constraint_list.first;
    say (get-indent) ~ "$this";
    $block($this);
    un-indent;
  }
}
