
class Failure is export {
  has Str $.file;
  has Int  $.line;

  submethod BUILD(:$!file, :$!line) {
    my ($path,) = $!file.split(':');
    $!file = $path;
  }
}
