
use v6.d;
use Utils;

class Behave {
  method run {
    for Utils.specs -> $spec {
      say $spec;

      my $content = $spec.IO.slurp.trim;

      say $content;
    }
  }
}
