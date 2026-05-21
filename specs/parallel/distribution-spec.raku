use BDD::Behave;
use BDD::Behave::Parallel::Distribution;
use BDD::Behave::SpecTree;

constant Suite        = BDD::Behave::SpecTree::Suite;
constant ExampleGroup = BDD::Behave::SpecTree::ExampleGroup;
constant Example      = BDD::Behave::SpecTree::Example;
constant Bucket       = BDD::Behave::Parallel::Distribution::Bucket;

sub make-example(:$line, :$file = '/abs/spec.raku'.IO, :$serial = False) {
  my $ex = Example.new(:description("ex-$line"), :$file, :$line, :block(sub { }));
  $ex.set-metadata(:serial(True)) if $serial;
  $ex;
}

sub make-group(@children, :$line, :$file = '/abs/spec.raku'.IO, :$split = False, :$serial = False) {
  my $g = ExampleGroup.new(:description("g-$line"), :$file, :$line);
  $g.set-metadata(:parallel-split(True)) if $split;
  $g.set-metadata(:serial(True)) if $serial;
  $g.add-child($_) for @children;
  $g;
}

sub make-suite(@children) {
  my $file = '/abs/spec.raku'.IO;
  my $s = Suite.new(:description('spec.raku'), :$file, :line(1));
  $s.add-child($_) for @children;
  $s;
}

describe 'collect-buckets and group affinity', {
  it 'puts every example in a top-level describe into one bucket', {
    my $g = make-group([make-example(:line(10)), make-example(:line(20))], :line(5));
    my $suite = make-suite([$g]);
    my @buckets = collect-buckets($suite);
    expect(@buckets.elems).to.be(1);
    expect(@buckets[0].examples.elems).to.be(2);
  }

  it 'treats a top-level example as its own bucket', {
    my $ex = make-example(:line(99));
    my $suite = make-suite([$ex]);
    my @buckets = collect-buckets($suite);
    expect(@buckets.elems).to.be(1);
  }

  it ':parallel-split splits a group into per-child buckets', {
    my $g = make-group(
      [make-example(:line(10)), make-example(:line(20)), make-example(:line(30))],
      :line(5), :split,
    );
    my $suite = make-suite([$g]);
    my @buckets = collect-buckets($suite);
    expect(@buckets.elems).to.be(3);
  }
}

describe 'effective-serial and serial split', {
  it 'inherits :serial from an enclosing group', {
    my $ex = make-example(:line(10));
    my $g = make-group([$ex], :line(5), :serial);
    make-suite([$g]);
    expect(effective-serial($ex)).to.be(True);
  }

  it 'separates a mixed group into a parallel and a serial bucket', {
    my $g = make-group([
      make-example(:line(10)),
      make-example(:line(20), :serial),
    ], :line(5));
    my $suite = make-suite([$g]);
    my @buckets = collect-buckets($suite);
    my ($par, $ser) = split-parallel-and-serial(@buckets);
    expect($par.elems).to.be(1);
    expect($par[0].examples.elems).to.be(1);
    expect($ser.elems).to.be(1);
    expect($ser[0].examples.elems).to.be(1);
  }
}

describe 'LPT distribution', {
  it 'returns one assignment list per worker', {
    my @asgn = distribute-lpt([], 4);
    expect(@asgn.elems).to.be(4);
  }

  it 'preserves total cost across workers', {
    my @buckets;
    for (10, 8, 5, 3) -> $cost {
      my $b = Bucket.new(:id("b$cost"), :file</abs/a.raku>);
      $b.add(make-example(:line($_))) for ^$cost;
      @buckets.push: $b;
    }
    my @asgn = distribute-lpt(@buckets, 2);
    my @loads = @asgn.map(-> @bs { @bs.map(*.cost).sum });
    expect(@loads.sum).to.be(26);
  }

  it 'rejects worker-count less than 1', {
    expect({ distribute-lpt([], 0) }).to.raise-error;
  }
}
