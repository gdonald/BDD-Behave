
use Indent;

class Expectation {
  has $!given;
  has $!compare = True;

  submethod BUILD(:$!given) {}

  method to {
    self;
  }

  method not {
    $!compare = False;
    self;
  }

  method be($expected) {
    my $result = $!given == $expected;
    $result = $!compare ?? $result !! !$result;

    do-indent;
    say (get-indent) ~ ($result ?? "SUCCESS" !! "FAILURE");
    un-indent;
    say '';
  }
}
