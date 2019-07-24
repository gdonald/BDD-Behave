
class Expectation {
  has $!given;

  submethod BUILD(:$!given) {}

  method to_eq($arg) {
    say '        ' ~ ($!given == $arg ?? "SUCCESS" !! "FAILURE");
    say '';
  }
}
