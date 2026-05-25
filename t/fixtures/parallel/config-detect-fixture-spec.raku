use BDD::Behave;

my $detect-path = %*ENV<BEHAVE_PARALLEL_DETECT> // '';

describe 'parallel detect fixture', {
  it 'records worker count to detect path', {
    if $detect-path.chars {
      my $worker-count = %*ENV<BEHAVE_WORKER_COUNT> // 'serial';
      $detect-path.IO.spurt($worker-count);
    }
    expect(True).to.be(True);
  }
}
