use BDD::Behave;
use BDD::Behave::Runner;

sub strip-ansi(Str $s --> Str) { $s.subst(/\e '[' \d+ 'm'/, '', :g) }

sub comparison-row(Real $delta-pct, Bool :$regression = False --> Hash) {
  %(
    description     => 'sum',
    key             => 'label:sum',
    baseline-median => 0.001,
    median          => 0.001 * (1 + $delta-pct),
    delta-pct       => $delta-pct,
    regression      => $regression,
  );
}

describe 'the delta cell of the benchmark comparison table', {
  let(:runner, { BDD::Behave::Runner::Runner.new(:benchmark-threshold(0.10)) });

  it 'marks a regression with an up arrow and the word REGRESSION', {
    expect(strip-ansi(runner().render-delta-cell(comparison-row(0.25, :regression))))
      .to.eq('↑ +25.0% REGRESSION');
  }

  it 'marks an improvement past the threshold with a down arrow', {
    expect(strip-ansi(runner().render-delta-cell(comparison-row(-0.25))))
      .to.eq('↓ -25.0%');
  }

  it 'marks a slowdown under the threshold with a plain up arrow', {
    expect(strip-ansi(runner().render-delta-cell(comparison-row(0.05))))
      .to.eq('↑ +5.0%');
  }

  it 'marks a speedup under the threshold with a plain down arrow', {
    expect(strip-ansi(runner().render-delta-cell(comparison-row(-0.05))))
      .to.eq('↓ -5.0%');
  }

  it 'marks an unchanged measurement with a right arrow', {
    expect(strip-ansi(runner().render-delta-cell(comparison-row(0))))
      .to.eq('→ +0.0%');
  }

  it 'leaves an improvement past the threshold colored green', {
    expect(runner().render-delta-cell(comparison-row(-0.25))).to.include("\e[32m");
  }

  it 'leaves a slowdown under the threshold uncolored', {
    expect(runner().render-delta-cell(comparison-row(0.05))).to.not.include("\e[");
  }
}

sub one-row(|c --> Array) {
  my @rows;
  @rows.push: comparison-row(|c);
  @rows;
}

describe 'the benchmark comparison table', {
  let(:runner, { BDD::Behave::Runner::Runner.new(:benchmark-threshold(0.10)) });

  it 'heads a table with no regressions by naming the threshold', {
    expect(strip-ansi(runner().render-bench-comparison-table(one-row(0.05))))
      .to.include('Benchmark comparison (no regressions; threshold 10.0%):');
  }

  it 'heads a table with regressions by counting them', {
    expect(strip-ansi(runner().render-bench-comparison-table(one-row(0.25, :regression))))
      .to.include('Benchmark regressions (1, threshold 10.0%):');
  }

  it 'names each column', {
    expect(strip-ansi(runner().render-bench-comparison-table(one-row(0.05))))
      .to.include('DESCRIPTION');
  }

  it 'renders the baseline median in seconds', {
    expect(strip-ansi(runner().render-bench-comparison-table(one-row(0.05))))
      .to.include('0.001000s');
  }
}
