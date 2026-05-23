use BDD::Behave;
use BDD::Behave::Parallel::Distribution;
use BDD::Behave::SpecTree;

constant Suite        = BDD::Behave::SpecTree::Suite;
constant ExampleGroup = BDD::Behave::SpecTree::ExampleGroup;
constant Example      = BDD::Behave::SpecTree::Example;
constant Bucket       = BDD::Behave::Parallel::Distribution::Bucket;

sub bucket(Str $id) {
  my $b = Bucket.new(:id($id), :file<x>);
  $b.add(Example.new(:description($id), :file('/x'.IO), :line(1), :block(sub { })));
  $b;
}

sub many-buckets(Int $n) {
  (^$n).map(-> $i { bucket("/abs/spec.raku#g0:{100 + $i}") }).List;
}

sub global-rank(Bucket $needle, @assignments, Int $worker-count) {
  for ^$worker-count -> $w {
    my $pos = @assignments[$w].first(* === $needle, :k);
    return $pos * $worker-count + $w if $pos.defined;
  }
  -1;
}

describe 'bucket-stable-key', {
  it 'returns the same hash for the same bucket and seed', {
    my $b = bucket('/abs/spec.raku#g0:10');
    my $h1 = bucket-stable-key($b, 42);
    my $h2 = bucket-stable-key($b, 42);
    expect($h1).to.be($h2);
  }

  it 'produces different hashes for different seeds (with high probability)', {
    my $b = bucket('/abs/spec.raku#g0:10');
    expect(bucket-stable-key($b, 1) != bucket-stable-key($b, 2)).to.be(True);
  }

  it 'produces different hashes for different bucket ids (with high probability)', {
    my $a = bucket('/abs/spec.raku#g0:10');
    my $c = bucket('/abs/spec.raku#g0:11');
    expect(bucket-stable-key($a, 42) != bucket-stable-key($c, 42)).to.be(True);
  }

  it 'returns a 32-bit unsigned integer', {
    my $b = bucket('/abs/spec.raku#g0:10');
    my $h = bucket-stable-key($b, 42);
    expect($h >= 0 && $h <= 0xFFFFFFFF).to.be(True);
  }
}

describe 'distribute-stable', {
  it 'rejects worker-count less than 1', {
    expect({ distribute-stable([], 0, 42) }).to.raise-error;
  }

  it 'returns one assignment list per worker', {
    my @bs = many-buckets(6);
    my @asgn = distribute-stable(@bs, 4, 42);
    expect(@asgn.elems).to.be(4);
  }

  it 'returns empty assignments when given no buckets', {
    my @asgn = distribute-stable([], 3, 42);
    expect(@asgn.map(*.elems).sum).to.be(0);
  }

  it 'assigns every bucket exactly once across all workers', {
    my @bs = many-buckets(13);
    my @asgn = distribute-stable(@bs, 4, 42);
    my $total = @asgn.map(*.elems).sum;
    expect($total).to.be(13);
  }

  it 'is deterministic: same input yields same per-worker assignments', {
    my @bs = many-buckets(7);
    my @a1 = distribute-stable(@bs, 3, 42);
    my @a2 = distribute-stable(@bs, 3, 42);
    for ^3 -> $w {
      my @ids1 = @a1[$w].map(*.id);
      my @ids2 = @a2[$w].map(*.id);
      expect(@ids1.join('|')).to.be(@ids2.join('|'));
    }
  }
}

describe 'distribute-stable: K-invariant global ordering', {
  it 'preserves each bucket\'s global rank when K changes from 2 to 3', {
    my @bs = many-buckets(12);

    my @a2 = distribute-stable(@bs, 2, 42);
    my @a3 = distribute-stable(@bs, 3, 42);

    for @bs -> $b {
      expect(global-rank($b, @a2, 2)).to.be(global-rank($b, @a3, 3));
    }
  }

  it 'preserves each bucket\'s global rank when K changes from 1 to 5', {
    my @bs = many-buckets(20);

    my @a1 = distribute-stable(@bs, 1, 7);
    my @a5 = distribute-stable(@bs, 5, 7);

    for @bs -> $b {
      expect(global-rank($b, @a1, 1)).to.be(global-rank($b, @a5, 5));
    }
  }

  it 'gives a different global order when the seed changes', {
    my @bs = many-buckets(8);

    my @asgn-a = distribute-stable(@bs, 2, 1);
    my @asgn-b = distribute-stable(@bs, 2, 9999);

    my @ranks-a;
    my @ranks-b;

    for @bs -> $b {
      @ranks-a.push: global-rank($b, @asgn-a, 2);
      @ranks-b.push: global-rank($b, @asgn-b, 2);
    }

    expect(@ranks-a.join(',')).not.to.be(@ranks-b.join(','));
  }
}

describe 'distribute-stable: within-worker order', {
  it 'orders each worker\'s buckets by stable key (sub-sequence of the global sort)', {
    my @bs = many-buckets(10);

    my @asgn = distribute-stable(@bs, 3, 42);

    for ^3 -> $w {
      my @keys = @asgn[$w].map({ bucket-stable-key($_, 42) });
      my @sorted = @keys.sort;
      expect(@keys.join(',')).to.be(@sorted.join(','));
    }
  }
}
