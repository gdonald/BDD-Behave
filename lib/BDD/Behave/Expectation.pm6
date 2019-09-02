
#unit class BDD::Behave::Expectation;

use BDD::Behave::Colors;
use BDD::Behave::Failure;
use BDD::Behave::Failures;
use BDD::Behave::Files;
use BDD::Behave::Indent;
use BDD::Behave::Lets;
use BDD::Behave::Value;

class Expectation is export {
  has Str $!raw;
  has Value $!given;
  has Bool $!compare = True;
  has Int $!line;

  submethod BUILD(:$!raw, :$!line) {
    $!given = Value.new(:$!raw);
  }

  method to { self }

  method not {
    $!compare = False;
    self;
  }

  method be($expect) {
    my Value $expected = Value.new(:raw($expect));
    my $result = $!given.get() ~~ $expected.get();

    $result = $!compare ?? $result !! !$result;

    if !$result {
      my $failure = Failure.new(:file(Files.current), :$!line);
      Failures.list.push($failure);
    }

    $result = $result ?? green('SUCCESS') !! red('FAILURE');
    indent-block -> 'do' { $result }
  }
}
