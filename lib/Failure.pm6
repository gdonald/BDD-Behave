
my Str $current-file;

sub set-current-file($file) is export {
  $current-file = $file;
}

sub get-current-file is export { $current-file }

class Failure {
  has Str $.file;
  has Str $.line;

  submethod BUILD(:$!file, :$!line) {}
}
