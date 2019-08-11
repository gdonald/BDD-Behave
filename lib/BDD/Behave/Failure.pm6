
unit class BDD::Behave::Failure;

class Failure is export {
  has Str $.file;
  has Str $.line;

  submethod BUILD(:$!file, :$!line) {
    my ($path,) = $!file.split(':');
    $!file = $path;
  }
}
