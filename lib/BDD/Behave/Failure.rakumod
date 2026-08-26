
class X::BDD::Behave::ExpectationFailed is Exception is export {
  has Str $.file;
  has Int $.line;
  method message(--> Str) { "expectation failed at {$!file}:{$!line}" }
}

class Failure is export {
  has Str $.file;
  has Int $.line;
  has $.given;
  has $.expected;
  has Bool $.negated = False;
  has Str  $.message;
  has Str  $.aggregation-label;
  has Bool $.from-runner-exception = False;
  has Str  $.description;

  submethod BUILD(
    :$!file, :$!line, Mu :$given is raw, Mu :$expected is raw,
    :$!negated = False, :$!message = Str, :$aggregation-label,
    Bool :$!from-runner-exception = False,
    Str  :$description,
  ) {
    $!given = $given;
    $!expected = $expected;
    my ($path,) = $!file.split(':');
    $!file = $path;
    if $aggregation-label.defined {
      $!aggregation-label = $aggregation-label;
    } else {
      try {
        $!aggregation-label = $*BEHAVE-AGGREGATION-LABEL
          if $*BEHAVE-AGGREGATION-LABEL.defined;
      }
    }
    if $description.defined {
      $!description = $description;
    } else {
      try {
        $!description = $*BEHAVE-CURRENT-DESCRIPTION
          if $*BEHAVE-CURRENT-DESCRIPTION.defined;
      }
    }
  }
}

# The rendered form of an expectation failure that carries no message of its
# own. The JSON event stream and the parallel parent both describe a failure
# through this, so an event carries the same fields whichever path produced it.
sub compose-failure-message($given, $expected, Bool $negated = False --> Str) is export {
  my $given-text    = ($given    // '').Str;
  my $expected-text = ($expected // '').Str;

  return '' unless $given-text.chars || $expected-text.chars;

  my $op = $negated ?? 'not to be' !! 'to be';

  "Expected: $given-text\n$op: $expected-text";
}
