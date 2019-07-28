
use Colors;
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
      my $failure = Failure.new(:file(Files.current), :line(callframe(1).line));
      Failures.list.push($failure);
    }

    $result = $result ?? green('SUCCESS') !! red('FAILURE');
    indent-block -> 'do' { $result }
  }
}
