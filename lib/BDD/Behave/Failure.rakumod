
class Failure is export {
  has Str $.file;
  has Int $.line;
  has $.given;
  has $.expected;
  has Bool $.negated = False;
  has Str  $.message;

  submethod BUILD(:$!file, :$!line, :$!given, :$!expected, :$!negated = False, :$!message = Str) {
    my ($path,) = $!file.split(':');
    $!file = $path;
  }
}
