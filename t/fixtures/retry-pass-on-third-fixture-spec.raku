use BDD::Behave;

my $attempts-file = %*ENV<BEHAVE_RETRY_ATTEMPTS_FILE>;

sub bump-attempt(--> Int) {
  return 0 unless $attempts-file.defined && $attempts-file.chars;

  my $path = $attempts-file.IO;
  my $current = $path.e ?? $path.slurp.trim.Int !! 0;
  my $next = $current + 1;
  $path.spurt: $next.Str;
  $next;
}

describe 'flaky example', {
  it 'passes on the third attempt', {
    my $n = bump-attempt;
    expect($n).to.be(3);
  }
}
