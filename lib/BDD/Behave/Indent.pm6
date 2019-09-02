
use BDD::Behave::Colors;

class Indent is export {
  my Int $.value = 0;

  method increase {
    Indent.value += 4;
  }

  method decrease {
    Indent.value -= 4;
  }

  method get {
    ' ' x Indent.value ~ light-blue('⮑  ');
  }
}

sub block-desc(Block $block) is export {
  $block.signature.params.first.constraint_list.first;
}

sub indent-block(Block $block) is export {
  indent -> 'do' {
    my $desc = block-desc($block);
    say Indent.get ~ $block($desc);
  }
}

sub indent(Block $block) is export {
  Indent.increase;
  my $desc = block-desc($block);
  $block($desc);
  Indent.decrease;
}
