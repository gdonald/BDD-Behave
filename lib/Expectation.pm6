
use Indent;
use Failure;

my @failures = [];

sub add-failure($file, $line) is export {
  my $failure = Failure.new(:$file, :$line);
  @failures.push($failure);
}

sub get-failures is export { @failures }

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
      add-failure(get-current-file, $frame.line);
    }

    $result = $result ?? green('SUCCESS') !! red('FAILURE');

    do-indent;
    say (get-indent) ~ $result ~ "\n";
    un-indent;
  }

  sub red($str) { "\e[31m" ~ $str ~ "\e[0m" }
  sub green($str) { "\e[32m" ~ $str ~ "\e[0m" }
}
