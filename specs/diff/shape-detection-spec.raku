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
    expect(diffable('hi', 'bye')).to.be-truthy;
    expect(diffable([1], [2])).to.be-truthy;
    expect(diffable({a => 1}, {b => 2})).to.be-truthy;
    expect(diffable((set <a>), (set <b>))).to.be-truthy;
    expect(diffable((bag <a>), (bag <b>))).to.be-truthy;
  }

  it 'returns False for plain scalars', {
    expect(diffable(1, 2)).to.be-falsy;
    expect(diffable(True, False)).to.be-falsy;
  }

  it 'returns False for mismatched shapes', {
    expect(diffable([1, 2], {a => 1})).to.be-falsy;
    expect(diffable('hi', [1])).to.be-falsy;
  }

  it 'returns False when either value is undefined', {
    expect(diffable(Nil, [1])).to.be-falsy;
    expect(diffable([1], Any)).to.be-falsy;
  }
}
