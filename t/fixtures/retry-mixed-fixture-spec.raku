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

describe 'mixed retry suite', {
  it 'always passes', {
    expect(1 + 1).to.be(2);
  }

  it 'flakes once then passes', :retry(2), {
    my $n = bump-attempt;
    expect($n).to.be(2);
  }

  it 'always fails', :retry(1), {
    expect(False).to.be-truthy;
  }
}
