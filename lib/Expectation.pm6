
use Indent;

class Expectation {
  has $!given;

  submethod BUILD(:$!given) {}

  method to_eq($arg) {
    do-indent;
    say (get-indent) ~ ($!given == $arg ?? "SUCCESS" !! "FAILURE");
    un-indent;
    say '';
  }
}
