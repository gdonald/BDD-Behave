use BDD::Behave;

my $marker-path = %*ENV<BEHAVE_CRASH_MARKER> // '';

describe 'shard crash fixture', {
  it 'crashes on first attempt, succeeds on retry', {
    if $marker-path.chars && $marker-path.IO.e {
      expect(True).to.be(True);
    } else {
      $marker-path.IO.spurt('crashed') if $marker-path.chars;
      exit 137;
    }
  }

  it 'passes plainly', {
    expect(1 + 1).to.be(2);
  }
}
