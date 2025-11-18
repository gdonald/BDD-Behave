
class Failure is export {
  has Str $.file;
  has Int $.line;
  has $.given;
  has $.expected;
  has Bool $.negated = False;

  submethod BUILD(:$!file, :$!line, :$!given, :$!expected, :$!negated = False) {
    my ($path,) = $!file.split(':');
    $!file = $path;
  }
}
