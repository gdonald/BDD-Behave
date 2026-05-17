unit module BDD::Behave::Benchmark;

our class BenchmarkResult {
  has Str  $.label;
  has Int  $.position;
  has Int  $.iterations is required;
  has      @.timings    is required;
  has Real $.min;
  has Real $.max;
  has Real $.mean;
  has Real $.median;
  has Real $.total;

  submethod TWEAK {
    return unless @!timings.elems;
    my @sorted = @!timings.sort;
    $!min   = @sorted[0];
    $!max   = @sorted[*-1];
    $!total = [+] @!timings;
    $!mean  = $!total / @!timings.elems;
    my $n   = @sorted.elems;
    $!median = $n %% 2
      ?? (@sorted[$n div 2 - 1] + @sorted[$n div 2]) / 2
      !! @sorted[$n div 2];
  }

  method key(--> Str) {
    $!label.defined ?? "label:$!label" !! "pos:" ~ ($!position // 0);
  }
}

sub attach-to-current-example(BenchmarkResult $result --> Nil) {
  my $current;
  try { $current = $*BEHAVE-CURRENT-EXAMPLE if $*BEHAVE-CURRENT-EXAMPLE.defined }
  return unless $current.defined;
  $current.benchmarks.push: $result;
}

sub next-position(--> Int) {
  my $pos = 0;
  try {
    if $*BEHAVE-BENCHMARK-COUNTER.defined {
      $pos = $*BEHAVE-BENCHMARK-COUNTER;
      $*BEHAVE-BENCHMARK-COUNTER++;
    }
  }
  $pos;
}

sub run-iterations(&block, Int $iterations, Int $warmup, $label --> BenchmarkResult) {
  die "benchmark iterations must be a positive integer (got: $iterations)"
    unless $iterations > 0;
  die "benchmark warmup must be 0 or a positive integer (got: $warmup)"
    if $warmup < 0;

  my $position = next-position();

  for ^$warmup { block() }

  my @timings;
  for ^$iterations {
    my $start = now;
    block();
    my $finish = now;
    @timings.push: ($finish - $start).Real;
  }

  my $result = BenchmarkResult.new(
    :label($label // Str),
    :$position,
    :$iterations,
    :@timings,
  );
  attach-to-current-example($result);
  $result;
}

our proto sub benchmark(|) is export {*}

our multi sub benchmark(&block, Int :$iterations = 100, Int :$warmup = 0, Str :$label) is export {
  run-iterations(&block, $iterations, $warmup, $label);
}

our multi sub benchmark(Str:D $label, &block, Int :$iterations = 100, Int :$warmup = 0) is export {
  run-iterations(&block, $iterations, $warmup, $label);
}
