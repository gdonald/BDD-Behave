
sub describe(Block $b) {
  my $this = $b.signature.params[0].constraint_list[0];
  say "  $this";
  $b($this);
}

sub it(Block $b) {
  my $this = $b.signature.params[0].constraint_list[0];
  say "    $this";
  $b($this);
}

class Expectation {
  has $!given;

  submethod BUILD(:$!given) {}

  method to_eq($arg) {
    say '      ' ~ ($!given == $arg ?? "SUCCESS" !! "FAILURE");
    say '';
  }
}

sub expect($given) {
  Expectation.new(:$given);
}

describe -> "this spec" {
  it -> "is succesful" {
    expect(42).to_eq(42);
  }
}

describe -> "this other spec" {
  it -> "is a big failure" {
    expect(42).to_eq(41);
  }
}
