use BDD::Behave;
use BDD::Behave::Runner;
use BDD::Behave::SpecTree;

need BDD::Behave::Benchmark;
need BDD::Behave::Benchmark::Baseline;
need BDD::Behave::Benchmark::Format;

constant Suite           = BDD::Behave::SpecTree::Suite;
constant ExampleGroup    = BDD::Behave::SpecTree::ExampleGroup;
constant Example         = BDD::Behave::SpecTree::Example;
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

sub strip-ansi(Str $s --> Str) { $s.subst(/\e '[' \d+ 'm'/, '', :g) }

describe 'Runner.benchmark-format validation', {
  it 'defaults to text', {
    my $r = BDD::Behave::Runner::Runner.new;
    expect($r.benchmark-format).to.be('text');
  }

  it 'accepts json', {
    my $r = BDD::Behave::Runner::Runner.new(:benchmark-format<json>);
    expect($r.benchmark-format).to.be('json');
  }

  it 'rejects an unknown format', {
    expect({
      BDD::Behave::Runner::Runner.new(:benchmark-format<xml>);
    }).to.raise-error(/'benchmark-format'/);
  }
}

describe 'Text table rendering', {
  it 'renders a table with header, rule, and one row per summary', {
    my $ex = make-example('one', {
      BDD::Behave::Benchmark::benchmark('sum', :iterations(2), { Nil });
    });
    my ($runner, $result) = silent-run(build-suite([$ex]), :benchmark-mode);
    my $rendered = strip-ansi(
      $runner.render-benchmark-output(
        $runner.benchmark-summaries, $runner.benchmark-regressions));
    expect($rendered.contains('DESCRIPTION')).to.be-truthy;
    expect($rendered.contains('KEY')).to.be-truthy;
    expect($rendered.contains('MEDIAN(s)')).to.be-truthy;
    expect($rendered.contains('label:sum')).to.be-truthy;
    expect($rendered.contains('─')).to.be-truthy;
  }

  it 'singularizes the heading for a single measurement', {
    my $ex = make-example('lonely', {
      BDD::Behave::Benchmark::benchmark(:iterations(1), { Nil });
    });
    my ($runner, $result) = silent-run(build-suite([$ex]), :benchmark-mode);
    my $rendered = strip-ansi(
      $runner.render-benchmark-output(
        $runner.benchmark-summaries, $runner.benchmark-regressions));
    expect($rendered.contains('Benchmarks (1 measurement):')).to.be-truthy;
  }

  it 'pluralizes the heading for multiple measurements', {
    my $ex = make-example('two', {
      BDD::Behave::Benchmark::benchmark('a', :iterations(1), { Nil });
      BDD::Behave::Benchmark::benchmark('b', :iterations(1), { Nil });
    });
    my ($runner, $result) = silent-run(build-suite([$ex]), :benchmark-mode);
    my $rendered = strip-ansi(
      $runner.render-benchmark-output(
        $runner.benchmark-summaries, $runner.benchmark-regressions));
    expect($rendered.contains('Benchmarks (2 measurements):')).to.be-truthy;
  }
}

describe 'Comparison arrows', {
  it 'renders an up arrow for a regression', {
    my $ex = make-example('regress', {
      BDD::Behave::Benchmark::benchmark('r', :iterations(1), { Nil });
    });
    my $tmp = $*TMPDIR.add("behave-rep-{$*PID}-{(now * 1e6).Int}.txt");
    my @entries = (
      BaselineEntry.new(
        :description('g regress'), :key('label:r'), :iterations(1),
        :min(1e-9), :max(1e-9), :mean(1e-9), :median(1e-9), :total(1e-9)),
    );
    BDD::Behave::Benchmark::Baseline::save($tmp, @entries);
    my ($runner, $result) = silent-run(
      build-suite([$ex]),
      :benchmark-mode, :benchmark-baseline($tmp), :benchmark-threshold(0.10),
    );
    my $rendered = strip-ansi(
      $runner.render-benchmark-output(
        $runner.benchmark-summaries, $runner.benchmark-regressions));
    expect($rendered.contains('↑')).to.be-truthy;
    expect($rendered.contains('REGRESSION')).to.be-truthy;
    $tmp.unlink;
  }

  it 'renders a down arrow for an improvement', {
    my $ex = make-example('faster', {
      BDD::Behave::Benchmark::benchmark('f', :iterations(1), { Nil });
    });
    my $tmp = $*TMPDIR.add("behave-rep2-{$*PID}-{(now * 1e6).Int}.txt");
    my @entries = (
      BaselineEntry.new(
        :description('g faster'), :key('label:f'), :iterations(1),
        :min(1e9), :max(1e9), :mean(1e9), :median(1e9), :total(1e9)),
    );
    BDD::Behave::Benchmark::Baseline::save($tmp, @entries);
    my ($runner, $result) = silent-run(
      build-suite([$ex]),
      :benchmark-mode, :benchmark-baseline($tmp), :benchmark-threshold(0.10),
    );
    my $rendered = strip-ansi(
      $runner.render-benchmark-output(
        $runner.benchmark-summaries, $runner.benchmark-regressions));
    expect($rendered.contains('↓')).to.be-truthy;
    expect($rendered.contains('REGRESSION')).to.be-falsy;
    $tmp.unlink;
  }
}

describe 'JSON output', {
  it 'is valid JSON containing benchmarks, regressions, threshold, version', {
    my $ex = make-example('json one', {
      BDD::Behave::Benchmark::benchmark('jk', :iterations(2), { Nil });
    });
    my ($runner, $result) = silent-run(
      build-suite([$ex]),
      :benchmark-mode, :benchmark-format<json>,
    );
    my $rendered = $runner.render-benchmark-output(
      $runner.benchmark-summaries, $runner.benchmark-regressions);
    expect($rendered.starts-with('{')).to.be-truthy;
    expect($rendered.ends-with('}')).to.be-truthy;
    expect($rendered.contains('"benchmarks":')).to.be-truthy;
    expect($rendered.contains('"regressions":')).to.be-truthy;
    expect($rendered.contains('"version":1')).to.be-truthy;
    expect($rendered.contains('"threshold":0.1')).to.be-truthy;
    expect($rendered.contains('"label:jk"')).to.be-truthy;
  }

  it 'includes the file and line for each benchmark entry', {
    my $ex = make-example('json file', {
      BDD::Behave::Benchmark::benchmark('jf', :iterations(1), { Nil });
    }, :line(99));
    my ($runner, $result) = silent-run(
      build-suite([$ex]),
      :benchmark-mode, :benchmark-format<json>,
    );
    my $rendered = $runner.render-benchmark-output(
      $runner.benchmark-summaries, $runner.benchmark-regressions);
    expect($rendered.contains('"file":')).to.be-truthy;
    expect($rendered.contains('"line":99')).to.be-truthy;
  }

  it 'emits regression entries when comparing against a baseline', {
    my $ex = make-example('json cmp', {
      BDD::Behave::Benchmark::benchmark('jc', :iterations(1), { Nil });
    });
    my $tmp = $*TMPDIR.add("behave-json-cmp-{$*PID}-{(now * 1e6).Int}.txt");
    my @entries = (
      BaselineEntry.new(
        :description('g json cmp'), :key('label:jc'), :iterations(1),
        :min(1e-9), :max(1e-9), :mean(1e-9), :median(1e-9), :total(1e-9)),
    );
    BDD::Behave::Benchmark::Baseline::save($tmp, @entries);
    my ($runner, $result) = silent-run(
      build-suite([$ex]),
      :benchmark-mode, :benchmark-format<json>,
      :benchmark-baseline($tmp), :benchmark-threshold(0.10),
    );
    my $rendered = $runner.render-benchmark-output(
      $runner.benchmark-summaries, $runner.benchmark-regressions);
    expect($rendered.contains('"regression":true')).to.be-truthy;
    expect($rendered.contains('"baseline-median":')).to.be-truthy;
    expect($rendered.contains('"delta-pct":')).to.be-truthy;
    $tmp.unlink;
  }

  it 'sorts object keys deterministically', {
    my %h = c => 1, a => 2, b => 3;
    my $json = BDD::Behave::Benchmark::Format::to-json(%h);
    expect($json).to.be('{"a":2,"b":3,"c":1}');
  }

  it 'escapes special characters in strings', {
    my $json = BDD::Behave::Benchmark::Format::to-json('a"b\\c' ~ "\n");
    expect($json).to.be('"a\"b\\\\c\n"');
  }
}

describe 'benchmark-output writes to a file instead of stdout', {
  it 'writes the same content that would have gone to stdout', {
    my $ex = make-example('output me', {
      BDD::Behave::Benchmark::benchmark('o', :iterations(1), { Nil });
    });
    my $tmp = $*TMPDIR.add("behave-rep-out-{$*PID}-{(now * 1e6).Int}.json");
    silent-run(
      build-suite([$ex]),
      :benchmark-mode, :benchmark-format<json>, :benchmark-output($tmp),
    );
    expect($tmp.e).to.be-truthy;
    my $content = $tmp.slurp;
    expect($content.contains('"label:o"')).to.be-truthy;
    $tmp.unlink;
  }
}
