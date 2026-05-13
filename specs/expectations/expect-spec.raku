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

describe 'expect basics', {
  it 'returns True for a passing positive expectation', {
    my $result = expect(42).to.be(42);
    expect($result).to.be-truthy;
  }

  it 'records no failure for a passing positive expectation', {
    my @new = induce({ expect(42).to.be(42) });
    expect(@new.elems).to.be(0);
  }

  it 'returns False for a failing positive expectation', {
    my $returned;
    my @new = induce({ $returned = expect(42).to.be(41) });
    expect($returned).to.be-falsy;
    expect(@new.elems).to.be(1);
  }

  it 'records given/expected/negated on a failing expectation', {
    my @new = induce({ expect(42).to.be(41) });
    my $f = @new[0];
    expect($f.given).to.be(42);
    expect($f.expected).to.be(41);
    expect($f.negated).to.be-falsy;
  }

  it 'returns True for a passing negated expectation', {
    my $returned;
    my @new = induce({ $returned = expect(42).to.not.be(41) });
    expect($returned).to.be-truthy;
    expect(@new.elems).to.be(0);
  }

  it 'returns False for a failing negated expectation', {
    my $returned;
    my @new = induce({ $returned = expect(42).to.not.be(42) });
    expect($returned).to.be-falsy;
    expect(@new.elems).to.be(1);
    expect(@new[0].negated).to.be-truthy;
  }

  it 'works with strings', {
    expect('hello').to.be('hello');
  }
}
