
use Colors;

class Failure {
  has Str $.file;
  has Str $.line;

  submethod BUILD(:$!file, :$!line) {
    my ($path,) = $!file.split(':');
    $!file = $path;
  }
}

class Failures {
  my @.list;

  method say {
    if Failures.list.elems {
      say red("Failures:") ~ "\n";
      for (Failures.list) -> $failure {
        say '  [' ~ red(" ✗ ") ~ '] ' ~ $failure.file ~ ':' ~ $failure.line;
      }
      say '';
    }
  }
}
