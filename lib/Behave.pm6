
use v6.d;
use MONKEY;
use Utils;

class Behave {
  method run {
    for Utils.specs -> $spec {
      say $spec;

      my $content = $spec.IO.slurp.trim;

      EVAL $content;
    }
  }
}
