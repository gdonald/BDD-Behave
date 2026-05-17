use BDD::Behave;
use BDD::Behave::Runner;
use BDD::Behave::SpecTree;

need BDD::Behave::Benchmark;

constant Suite           = BDD::Behave::SpecTree::Suite;
constant ExampleGroup    = BDD::Behave::SpecTree::ExampleGroup;
constant Example         = BDD::Behave::SpecTree::Example;
constant BenchmarkResult = BDD::Behave::Benchmark::BenchmarkResult;

sub silent-run($suite, *%runner-args) {
  my $sink = open '/dev/null', :w;
  my $*OUT = $sink;
  my $runner = BDD::Behave::Runner::Runner.new(|%runner-args);
  my $result = $runner.run($suite);
  $sink.close;
  $result;
}

sub build-suite(@examples) {
  my $suite = Suite.create(:description('benchmark'), :file('synthetic'.IO), :line(1));
  my $group = ExampleGroup.new(:description('g'), :file('synthetic'.IO), :line(1));
  $suite.add-group($group);
  $group.add-example($_) for @examples;
  $suite;
}

describe 'BenchmarkResult', {
  it 'computes min, max, mean, median, total from timings', {
    my $r = BenchmarkResult.new(
      :iterations(5),
      :timings(0.10, 0.20, 0.30, 0.40, 0.50),
    );
    expect($r.min).to.be(0.10);
    expect($r.max).to.be(0.50);
    expect($r.total).to.be(1.50);
    expect($r.mean).to.be(0.30);
    expect($r.median).to.be(0.30);
  }

  it 'computes median for an even number of iterations as the mean of two middles', {
    my $r = BenchmarkResult.new(
      :iterations(4),
      :timings(0.10, 0.20, 0.30, 0.40),
    );
    expect($r.median).to.be(0.25);
  }

  it 'sorts unordered timings when computing min and max', {
    my $r = BenchmarkResult.new(
      :iterations(3),
      :timings(0.30, 0.10, 0.20),
    );
    expect($r.min).to.be(0.10);
    expect($r.max).to.be(0.30);
    expect($r.median).to.be(0.20);
  }

  it 'records iterations and the original timings list', {
    my @t = 0.01, 0.02, 0.03;
    my $r = BenchmarkResult.new(:iterations(3), :timings(@t));
    expect($r.iterations).to.be(3);
    expect($r.timings.elems).to.be(3);
  }

  it 'carries an optional label', {
    my $unlabeled = BenchmarkResult.new(:iterations(1), :timings(0.01));
    my $labeled   = BenchmarkResult.new(:iterations(1), :timings(0.01), :label('hashing'));
    expect($unlabeled.label.defined).to.be-falsy;
    expect($labeled.label).to.be('hashing');
  }
}

describe 'benchmark helper', {
  it 'returns a BenchmarkResult', {
    my $r = benchmark :iterations(3), { 1 + 1 };
    expect($r ~~ BenchmarkResult).to.be-truthy;
  }

  it 'defaults to 100 iterations', {
    my $r = benchmark { Nil };
    expect($r.iterations).to.be(100);
    expect($r.timings.elems).to.be(100);
  }

  it 'honors a custom iteration count', {
    my $r = benchmark :iterations(7), { Nil };
    expect($r.iterations).to.be(7);
    expect($r.timings.elems).to.be(7);
  }

  it 'runs warmup iterations without recording them', {
    my $calls = 0;
    my $r = benchmark :iterations(5), :warmup(3), { $calls++ };
    expect($r.iterations).to.be(5);
    expect($r.timings.elems).to.be(5);
    expect($calls).to.be(8);
  }

  it 'records non-negative timings', {
    my $r = benchmark :iterations(5), { Nil };
    for $r.timings -> $t {
      expect($t).to.be-greater-than-or-equal-to(0);
    }
  }

  it 'accepts a positional Str label and applies named options', {
    my $r = benchmark 'fast path', :iterations(4), { Nil };
    expect($r.label).to.be('fast path');
    expect($r.iterations).to.be(4);
  }

  it 'rejects zero iterations', {
    expect({ benchmark :iterations(0), { Nil } }).to.raise-error(/'iterations'/);
  }

  it 'rejects negative iterations', {
    expect({ benchmark :iterations(-1), { Nil } }).to.raise-error(/'iterations'/);
  }

  it 'rejects negative warmup', {
    expect({ benchmark :iterations(1), :warmup(-1), { Nil } }).to.raise-error(/'warmup'/);
  }

  it 'returns a result even when called outside an example', {
    my $r = benchmark :iterations(2), { Nil };
    expect($r ~~ BenchmarkResult).to.be-truthy;
  }
}

describe 'benchmark attaches to the current example', {
  it 'starts with an empty benchmarks list on the example', {
    my $ex = Example.new(
      :description('inert'),
      :file('synthetic'.IO), :line(1),
      :block({ True }),
    );
    expect($ex.benchmarks.elems).to.be(0);
  }

  it 'pushes a result onto the example.benchmarks when called from a body', {
    my $ex = Example.new(
      :description('with benchmark'),
      :file('synthetic'.IO), :line(2),
      :block({
        benchmark :iterations(3), { Nil };
      }),
    );
    silent-run(build-suite([$ex]));
    expect($ex.benchmarks.elems).to.be(1);
    expect($ex.benchmarks[0] ~~ BenchmarkResult).to.be-truthy;
    expect($ex.benchmarks[0].iterations).to.be(3);
  }

  it 'collects multiple benchmark calls in declaration order', {
    my $ex = Example.new(
      :description('two benchmarks'),
      :file('synthetic'.IO), :line(3),
      :block({
        benchmark 'alpha', :iterations(2), { Nil };
        benchmark 'beta',  :iterations(2), { Nil };
      }),
    );
    silent-run(build-suite([$ex]));
    expect($ex.benchmarks.elems).to.be(2);
    expect($ex.benchmarks[0].label).to.be('alpha');
    expect($ex.benchmarks[1].label).to.be('beta');
  }

  it 'does not attach to skipped examples', {
    my $ex = Example.new(
      :description('skipped'),
      :file('synthetic'.IO), :line(4),
      :block({ benchmark :iterations(1), { Nil } }),
    );
    $ex.set-metadata(:skipped(True));
    silent-run(build-suite([$ex]));
    expect($ex.benchmarks.elems).to.be(0);
  }

  it 'does not attach to pending examples', {
    my $ex = Example.new(
      :description('pending'),
      :file('synthetic'.IO), :line(5),
      :block({ benchmark :iterations(1), { Nil } }),
    );
    $ex.mark-pending;
    silent-run(build-suite([$ex]));
    expect($ex.benchmarks.elems).to.be(0);
  }

  it 'isolates benchmarks per example', {
    my $a = Example.new(
      :description('a'),
      :file('synthetic'.IO), :line(6),
      :block({ benchmark :iterations(2), { Nil } }),
    );
    my $b = Example.new(
      :description('b'),
      :file('synthetic'.IO), :line(7),
      :block({ Nil }),
    );
    silent-run(build-suite([$a, $b]), :order<defined>);
    expect($a.benchmarks.elems).to.be(1);
    expect($b.benchmarks.elems).to.be(0);
  }
}
