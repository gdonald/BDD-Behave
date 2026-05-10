use BDD::Behave;
use BDD::Behave::Failures;

# Helper to splice off failures introduced inside a block, so a deliberately
# failing expectation does not poison the surrounding example.
sub induce(&block --> List) {
  my $start = Failures.list.elems;
  block();
  my @new = Failures.list[$start..^Failures.list.elems];
  Failures.list = Failures.list[^$start];
  @new.List;
}

class Point {
  has $.x;
  has $.y;
}

describe 'expect with real Raku values', {
  it 'compares Ints', {
    expect(42).to.be(42);
  }

  it 'compares Rats', {
    expect(3.14).to.be(3.14);
  }

  it 'compares Strs', {
    expect("hello world").to.be("hello world");
  }

  it 'compares Arrays via smartmatch', {
    my @a = [1, 2, 3];
    my @b = [1, 2, 3];
    expect(@a).to.be(@b);
  }

  it 'permits Int vs numeric-Str via smartmatch', {
    my @new = induce({ expect(42).to.be("42") });
    expect(@new.elems).to.be(0);
  }

  it 'compares object identity', {
    my $p = Point.new(:x(10), :y(20));
    expect($p).to.be($p);
  }

  it 'compares Nil to Nil', {
    expect(Nil).to.be(Nil);
  }

  it 'supports negation against actual values', {
    my @new = induce({ expect(42).to.not.be(43) });
    expect(@new.elems).to.be(0);
  }

  it 'stores the actual Array values on a failure (not stringified)', {
    my @actual   = [1, 2, 3];
    my @expected = [4, 5, 6];
    my @new = induce({ expect(@actual).to.be(@expected) });

    expect(@new.elems).to.be(1);
    expect(@new[0].given ~~ Array).to.be(True);
    expect(@new[0].expected ~~ Array).to.be(True);
  }
}
