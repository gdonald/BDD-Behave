
class Context {
  has Block $!block;

  submethod BUILD(:$!block) {
    my $this = $!block.signature.params[0].constraint_list[0];
    say "    $this";
    $!block($this);
  }
}
