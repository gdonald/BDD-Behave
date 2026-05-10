use BDD::Behave;
use BDD::Behave::Failures;

# These specs deliberately trigger failing expectations to verify how
# `expect` records them. After each induced failure we splice the new entries
# off Failures.list so the example itself passes.
sub induce(&block --> List) {
  my $start = Failures.list.elems;
  block();
  my @new = Failures.list[$start..^Failures.list.elems];
  Failures.list = Failures.list[^$start];
  @new.List;
}

# Behave's smartmatch matcher cannot directly check Bool values
# (False ~~ False is False under smartmatch). Coerce to 0/1 first.
sub bool-as-int(Bool $b --> Int) { $b ?? 1 !! 0 }

describe 'expect basics', {
  it 'returns True for a passing positive expectation', {
    my $result = expect(42).to.be(42);
    expect(bool-as-int($result)).to.be(1);
  }

  it 'records no failure for a passing positive expectation', {
    my @new = induce({ expect(42).to.be(42) });
    expect(@new.elems).to.be(0);
  }

  it 'returns False for a failing positive expectation', {
    my $returned;
    my @new = induce({ $returned = expect(42).to.be(41) });
    expect(bool-as-int($returned)).to.be(0);
    expect(@new.elems).to.be(1);
  }

  it 'records given/expected/negated on a failing expectation', {
    my @new = induce({ expect(42).to.be(41) });
    my $f = @new[0];
    expect($f.given).to.be(42);
    expect($f.expected).to.be(41);
    expect(bool-as-int($f.negated.so)).to.be(0);
  }

  it 'returns True for a passing negated expectation', {
    my $returned;
    my @new = induce({ $returned = expect(42).to.not.be(41) });
    expect(bool-as-int($returned)).to.be(1);
    expect(@new.elems).to.be(0);
  }

  it 'returns False for a failing negated expectation', {
    my $returned;
    my @new = induce({ $returned = expect(42).to.not.be(42) });
    expect(bool-as-int($returned)).to.be(0);
    expect(@new.elems).to.be(1);
    expect(bool-as-int(@new[0].negated.so)).to.be(1);
  }

  it 'works with strings', {
    expect('hello').to.be('hello');
  }
}
