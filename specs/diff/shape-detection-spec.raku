use BDD::Behave;
use BDD::Behave::Diff;

describe 'diff-shape', {
  it 'detects strings', {
    expect(diff-shape('hello')).to.be('Str');
  }

  it 'detects arrays', {
    expect(diff-shape([1, 2, 3])).to.be('Array');
    expect(diff-shape((1, 2, 3))).to.be('Array');
  }

  it 'detects hashes', {
    expect(diff-shape({a => 1})).to.be('Hash');
    expect(diff-shape({})).to.be('Hash');
  }

  it 'detects sets', {
    expect(diff-shape(set <a b c>)).to.be('Set');
    expect(diff-shape(SetHash.new(<a b>))).to.be('Set');
  }

  it 'detects bags', {
    expect(diff-shape(bag <a a b>)).to.be('Bag');
    expect(diff-shape(BagHash.new(<a b b>))).to.be('Bag');
  }

  it 'detects mixes', {
    expect(diff-shape(Mix.new-from-pairs((a => 1.5), (b => 2.5)))).to.be('Mix');
    expect(diff-shape(MixHash.new-from-pairs((a => 1.0)))).to.be('Mix');
  }

  it 'returns Scalar for plain values', {
    expect(diff-shape(42)).to.be('Scalar');
    expect(diff-shape(3.14)).to.be('Scalar');
    expect(diff-shape(True)).to.be('Scalar');
  }

  it 'returns Undef for undefined values', {
    expect(diff-shape(Nil)).to.be('Undef');
    expect(diff-shape(Any)).to.be('Undef');
  }
}

describe 'diffable', {
  it 'returns True for matching shapes that are structural', {
    expect(diffable('hi', 'bye') ?? 1 !! 0).to.be(1);
    expect(diffable([1], [2]) ?? 1 !! 0).to.be(1);
    expect(diffable({a => 1}, {b => 2}) ?? 1 !! 0).to.be(1);
    expect(diffable((set <a>), (set <b>)) ?? 1 !! 0).to.be(1);
    expect(diffable((bag <a>), (bag <b>)) ?? 1 !! 0).to.be(1);
  }

  it 'returns False for plain scalars', {
    expect(diffable(1, 2) ?? 1 !! 0).to.be(0);
    expect(diffable(True, False) ?? 1 !! 0).to.be(0);
  }

  it 'returns False for mismatched shapes', {
    expect(diffable([1, 2], {a => 1}) ?? 1 !! 0).to.be(0);
    expect(diffable('hi', [1]) ?? 1 !! 0).to.be(0);
  }

  it 'returns False when either value is undefined', {
    expect(diffable(Nil, [1]) ?? 1 !! 0).to.be(0);
    expect(diffable([1], Any) ?? 1 !! 0).to.be(0);
  }
}
