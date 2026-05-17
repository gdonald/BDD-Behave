use BDD::Behave;
use BDD::Behave::Runner;
use BDD::Behave::SpecTree;

need BDD::Behave::Benchmark;
need BDD::Behave::Benchmark::Baseline;

constant Suite           = BDD::Behave::SpecTree::Suite;
constant ExampleGroup    = BDD::Behave::SpecTree::ExampleGroup;
constant Example         = BDD::Behave::SpecTree::Example;
constant BenchmarkResult = BDD::Behave::Benchmark::BenchmarkResult;
constant BaselineEntry   = BDD::Behave::Benchmark::Baseline::BaselineEntry;

sub silent-run($suite, *%runner-args) {
  my $sink = open '/dev/null', :w;
  my $*OUT = $sink;
  my $runner = BDD::Behave::Runner::Runner.new(|%runner-args);
  my $result = $runner.run($suite);
  $sink.close;
  ($runner, $result);
}

sub make-example(Str $description, &block, Int :$line = 1) {
  Example.new(:$description, :file('synthetic'.IO), :$line, :&block);
}

sub build-suite(@examples, Str :$desc = 'bench') {
  my $suite = Suite.create(:description($desc), :file('synthetic'.IO), :line(1));
  my $group = ExampleGroup.new(:description('g'), :file('synthetic'.IO), :line(1));
  $suite.add-group($group);
  $group.add-example($_) for @examples;
  $suite;
}

describe 'BenchmarkResult key', {
  it 'uses label when present', {
    my $r = BenchmarkResult.new(
      :label('sum'), :position(0), :iterations(1), :timings(0.01),
    );
    expect($r.key).to.be('label:sum');
  }

  it 'falls back to position when no label is set', {
    my $r = BenchmarkResult.new(
      :position(2), :iterations(1), :timings(0.01),
    );
    expect($r.key).to.be('pos:2');
  }

  it 'falls back to pos:0 when neither label nor position are set', {
    my $r = BenchmarkResult.new(:iterations(1), :timings(0.01));
    expect($r.key).to.be('pos:0');
  }
}

describe 'benchmark position counter', {
  it 'assigns 0-based positions to sibling calls within a body', {
    my $ex = make-example('siblings', {
      BDD::Behave::Benchmark::benchmark(:iterations(1), { Nil });
      BDD::Behave::Benchmark::benchmark(:iterations(1), { Nil });
      BDD::Behave::Benchmark::benchmark(:iterations(1), { Nil });
    });
    silent-run(build-suite([$ex]));
    expect($ex.benchmarks[0].position).to.be(0);
    expect($ex.benchmarks[1].position).to.be(1);
    expect($ex.benchmarks[2].position).to.be(2);
  }

  it 'resets the counter on each body invocation across re-runs', {
    my $ex = make-example('two per body', {
      BDD::Behave::Benchmark::benchmark(:iterations(1), { Nil });
      BDD::Behave::Benchmark::benchmark(:iterations(1), { Nil });
    });
    silent-run(
      build-suite([$ex]),
      :benchmark-mode, :benchmark-iterations(2),
    );
    expect($ex.benchmarks.elems).to.be(4);
    expect($ex.benchmarks[0].position).to.be(0);
    expect($ex.benchmarks[1].position).to.be(1);
    expect($ex.benchmarks[2].position).to.be(0);
    expect($ex.benchmarks[3].position).to.be(1);
  }
}

describe 'Runner benchmark-mode validation', {
  it 'rejects zero benchmark-iterations', {
    expect({ BDD::Behave::Runner::Runner.new(:benchmark-iterations(0)) })
      .to.raise-error(/'benchmark-iterations'/);
  }

  it 'rejects negative benchmark-iterations', {
    expect({ BDD::Behave::Runner::Runner.new(:benchmark-iterations(-1)) })
      .to.raise-error(/'benchmark-iterations'/);
  }

  it 'rejects negative benchmark-threshold', {
    expect({ BDD::Behave::Runner::Runner.new(:benchmark-threshold(-0.5)) })
      .to.raise-error(/'benchmark-threshold'/);
  }
}

describe 'Runner.execute-benchmark-mode', {
  it 'is a no-op when benchmark-mode is off', {
    my $ex = make-example('off', {
      BDD::Behave::Benchmark::benchmark(:iterations(1), { Nil });
    });
    my ($runner, $result) = silent-run(build-suite([$ex]));
    expect($runner.benchmark-summaries.elems).to.be(0);
  }

  it 'collects one summary per benchmarked example with a single label', {
    my $ex = make-example('single', {
      BDD::Behave::Benchmark::benchmark('one', :iterations(2), { Nil });
    });
    my ($runner, $result) = silent-run(build-suite([$ex]), :benchmark-mode);
    expect($runner.benchmark-summaries.elems).to.be(1);
    expect($runner.benchmark-summaries[0]<key>).to.be('label:one');
  }

  it 'does not inflate test result counts when re-running benchmarked examples', {
    my $ex = make-example('counted once', {
      BDD::Behave::Benchmark::benchmark(:iterations(1), { Nil });
    });
    my ($runner, $result) = silent-run(
      build-suite([$ex]),
      :benchmark-mode, :benchmark-iterations(4),
    );
    expect($result.total).to.be(1);
    expect($result.passed).to.be(1);
    expect($result.failed).to.be(0);
  }

  it 'skips examples that did not register a benchmark', {
    my $with    = make-example('with',    {
      BDD::Behave::Benchmark::benchmark(:iterations(1), { Nil });
    }, :line(10));
    my $without = make-example('without', { Nil }, :line(11));
    my ($runner, $result) = silent-run(
      build-suite([$with, $without]),
      :benchmark-mode, :benchmark-iterations(2), :order<defined>,
    );
    expect($runner.benchmark-summaries.elems).to.be(1);
    expect($without.benchmarks.elems).to.be(0);
  }

  it 'aggregates per-key timings across re-runs', {
    my $ex = make-example('accumulate', {
      BDD::Behave::Benchmark::benchmark(:iterations(2), { Nil });
    });
    my ($runner, $result) = silent-run(
      build-suite([$ex]),
      :benchmark-mode, :benchmark-iterations(3),
    );
    my %s = $runner.benchmark-summaries[0];
    expect(%s<runs>).to.be(3);
    expect(%s<timings>.elems).to.be(6);
  }
}

describe 'Benchmark baseline file', {
  it 'serializes and parses round-trip', {
    my @entries = (
      BaselineEntry.new(
        :description('alpha'), :key('label:a'), :iterations(1),
        :min(0.1), :max(0.1), :mean(0.1), :median(0.1), :total(0.1)),
      BaselineEntry.new(
        :description('beta'), :key('pos:0'), :iterations(2),
        :min(0.2), :max(0.2), :mean(0.2), :median(0.2), :total(0.4)),
    );
    my $text = BDD::Behave::Benchmark::Baseline::serialize(@entries);
    my @parsed = BDD::Behave::Benchmark::Baseline::parse($text);
    expect(@parsed.elems).to.be(2);
    expect(@parsed[0].description).to.be('alpha');
    expect(@parsed[1].key).to.be('pos:0');
  }

  it 'rejects content missing the header', {
    expect({
      BDD::Behave::Benchmark::Baseline::parse("garbage\n")
    }).to.raise-error(/'header'/);
  }

  it 'rejects entries with the wrong column count', {
    my $bad = "# behave-benchmark-baseline v1\n"
            ~ "description\tkey\titerations\tmin\tmax\tmean\tmedian\ttotal\n"
            ~ "only\ttwo\n";
    expect({
      BDD::Behave::Benchmark::Baseline::parse($bad)
    }).to.raise-error(/'column count'/);
  }

  it 'persists and loads through the filesystem', {
    my $tmp = $*TMPDIR.add("behave-bench-baseline-spec-{$*PID}-{(now * 1e6).Int}.txt");
    my @entries = (
      BaselineEntry.new(
        :description('foo'), :key('label:bar'), :iterations(5),
        :min(0.001), :max(0.005), :mean(0.003), :median(0.003), :total(0.015)),
    );
    BDD::Behave::Benchmark::Baseline::save($tmp, @entries);
    expect($tmp.e).to.be-truthy;
    my @loaded = BDD::Behave::Benchmark::Baseline::load($tmp);
    expect(@loaded[0].description).to.be('foo');
    expect(@loaded[0].iterations).to.be(5);
    $tmp.unlink;
  }
}

describe 'Runner.save-benchmark-baseline', {
  it 'writes a baseline file containing current summaries', {
    my $ex = make-example('save me', {
      BDD::Behave::Benchmark::benchmark('saved', :iterations(2), { Nil });
    });
    my $tmp = $*TMPDIR.add("behave-save-spec-{$*PID}-{(now * 1e6).Int}.txt");
    silent-run(
      build-suite([$ex]),
      :benchmark-mode, :benchmark-save($tmp),
    );
    expect($tmp.e).to.be-truthy;
    my @loaded = BDD::Behave::Benchmark::Baseline::load($tmp);
    expect(@loaded[0].key).to.be('label:saved');
    $tmp.unlink;
  }
}

describe 'Runner.compare-with-baseline', {
  it 'flags entries whose median exceeds baseline by more than threshold', {
    my $ex = make-example('compare me', {
      BDD::Behave::Benchmark::benchmark('cmp', :iterations(2), { Nil });
    });
    my $tmp = $*TMPDIR.add("behave-cmp-spec-{$*PID}-{(now * 1e6).Int}.txt");
    my @entries = (
      BaselineEntry.new(
        :description('g compare me'),
        :key('label:cmp'),
        :iterations(2),
        :min(1e-9), :max(1e-9), :mean(1e-9),
        :median(1e-9), :total(2e-9),
      ),
    );
    BDD::Behave::Benchmark::Baseline::save($tmp, @entries);
    my ($runner, $result) = silent-run(
      build-suite([$ex]),
      :benchmark-mode,
      :benchmark-baseline($tmp),
      :benchmark-threshold(0.10),
    );
    expect($runner.benchmark-regressions.elems).to.be(1);
    expect($runner.benchmark-regressions[0]<regression>).to.be-truthy;
    $tmp.unlink;
  }

  it 'does not flag entries within threshold', {
    my $ex = make-example('quick', {
      BDD::Behave::Benchmark::benchmark('quick', :iterations(2), { Nil });
    });
    my $tmp = $*TMPDIR.add("behave-cmp-spec2-{$*PID}-{(now * 1e6).Int}.txt");
    my @entries = (
      BaselineEntry.new(
        :description('g quick'),
        :key('label:quick'),
        :iterations(2),
        :min(1e9), :max(1e9), :mean(1e9), :median(1e9), :total(2e9),
      ),
    );
    BDD::Behave::Benchmark::Baseline::save($tmp, @entries);
    my ($runner, $result) = silent-run(
      build-suite([$ex]),
      :benchmark-mode,
      :benchmark-baseline($tmp),
      :benchmark-threshold(0.10),
    );
    expect($runner.benchmark-regressions[0]<regression>).to.be-falsy;
    $tmp.unlink;
  }

  it 'silently ignores baseline entries that do not match any current summary', {
    my $ex = make-example('no match', {
      BDD::Behave::Benchmark::benchmark('x', :iterations(1), { Nil });
    });
    my $tmp = $*TMPDIR.add("behave-cmp-spec3-{$*PID}-{(now * 1e6).Int}.txt");
    my @entries = (
      BaselineEntry.new(
        :description('something else'),
        :key('label:other'),
        :iterations(1),
        :min(0.001), :max(0.001), :mean(0.001), :median(0.001), :total(0.001),
      ),
    );
    BDD::Behave::Benchmark::Baseline::save($tmp, @entries);
    my ($runner, $result) = silent-run(
      build-suite([$ex]),
      :benchmark-mode, :benchmark-baseline($tmp),
    );
    expect($runner.benchmark-regressions.elems).to.be(0);
    $tmp.unlink;
  }
}
