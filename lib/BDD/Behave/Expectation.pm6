
unit class BDD::Behave::Expectation;

use BDD::Behave::Colors;
use BDD::Behave::Failure;
use BDD::Behave::Failures;
use BDD::Behave::Files;
use BDD::Behave::Indent;
use BDD::Behave::Lets;

class Expectation is export {
  has $!given;
  has $!compare = True;
  has $!line;
  has Lets $!lets;

  submethod BUILD(:$!given, :$!lets, :$!line) {
    $!given = self.value($!given);
  }

  method to { self }

  method not {
    $!compare = False;
    self;
  }

  method be($expect) {
    my $expected = self.value($expect);
    my $result = $!given ~~ $expected;

    $result = $!compare ?? $result !! !$result;

    if !$result {
      my $failure = Failure.new(:file(Files.current), :$!line);
      Failures.list.push($failure);
    }

    $result = $result ?? green('SUCCESS') !! red('FAILURE');
    indent-block -> 'do' { $result }
  }

  method value($thing) {
    given $thing {
      when .Str ~~ /^\:/ { $!lets.get($thing.Str) }
      when +$_ ~~ Numeric { +$_ }
      when .WHAT ~~ Match { $thing.Str }
      default { die "Unknown \$thing: $_" }
    }
  }
}
