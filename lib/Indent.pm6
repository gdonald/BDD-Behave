
my Int $indent = 0;

sub do-indent is export { $indent += 2 }
sub un-indent is export { $indent -= 2 }
sub get-indent is export { ' ' x $indent }
