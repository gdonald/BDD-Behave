
class Failure is export {
  has Str $.file;
  has Int $.line;
  has $.given;
  has $.expected;
  has Bool $.negated = False;
  has Str  $.message;
  has Str  $.aggregation-label;

  submethod BUILD(
    :$!file, :$!line, :$!given, :$!expected,
    :$!negated = False, :$!message = Str, :$aggregation-label,
  ) {
    my ($path,) = $!file.split(':');
    $!file = $path;
    if $aggregation-label.defined {
      $!aggregation-label = $aggregation-label;
    } else {
      try {
        $!aggregation-label = $*BEHAVE-AGGREGATION-LABEL
          if $*BEHAVE-AGGREGATION-LABEL.defined;
      }
    }
  }
}
