
use Indent;
use Failures;
use Files;

class Expectation {
  has $!given;
  has $!compare = True;

  submethod BUILD(:$!given) {}

  method to { self }

  method not {
    $!compare = False;
    self;
  }

  method be($expected) {
    my $result = $!given == $expected;
    $result = $!compare ?? $result !! !$result;

    if !$result {
      my $frame = callframe(1);
      my Failure $failure = Failure.new(:file(Files.current), :line($frame.line));
      Failures.list.push($failure);
    }

    $result = $result ?? green('SUCCESS') !! red('FAILURE');

    Indent.increase;
    say Indent.get ~ $result ~ "\n";
    Indent.decrease;
  }

  sub red($str) { "\e[31m" ~ $str ~ "\e[0m" }
  sub green($str) { "\e[32m" ~ $str ~ "\e[0m" }
}
