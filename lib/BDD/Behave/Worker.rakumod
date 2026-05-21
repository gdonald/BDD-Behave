unit class BDD::Behave::Worker;

method id(--> Int) {
  my $raw = %*ENV<BEHAVE_WORKER_INDEX>;
  return 0 unless $raw.defined && $raw ~~ /^ \d+ $/;
  $raw.Int;
}

method count(--> Int) {
  my $raw = %*ENV<BEHAVE_WORKER_COUNT>;
  return 1 unless $raw.defined && $raw ~~ /^ \d+ $/ && $raw.Int > 0;
  $raw.Int;
}
