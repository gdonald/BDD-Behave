use BDD::Behave;
use BDD::Behave::Failures;

sub induce(&block --> List) { capture-failures(&block) }

multi sub is-junction(Junction:D --> Bool) { True }
multi sub is-junction($                --> Bool) { False }

describe 'expect with any junction', {
  it 'passes when actual equals one alternative via `|`', {
    expect(2).to.be(1 | 2 | 3);
  }

  it 'passes when actual equals one alternative via `any(...)`', {
    expect('green').to.be(any('red', 'green', 'blue'));
  }

  it 'fails when actual matches no alternative', {
    my $returned;
    my @new = induce({ $returned = expect(5).to.be(1 | 2 | 3) });
    expect($returned).to.be-falsy;
    expect(@new.elems).to.be(1);
  }

  it 'records the junction as Failure.expected', {
    my @new = induce({ expect(5).to.be(1 | 2 | 3) });
    expect(is-junction(@new[0].expected)).to.be-truthy;
    expect(@new[0].given).to.be(5);
  }

  it 'composes with .not when actual matches an alternative', {
    my $returned;
    my @new = induce({ $returned = expect(2).to.not.be(1 | 2 | 3) });
    expect($returned).to.be-falsy;
    expect(@new.elems).to.be(1);
    expect(@new[0].negated).to.be-truthy;
  }

  it 'passes negation when actual is outside the junction', {
    expect(5).to.not.be(1 | 2 | 3);
  }

  it 'works with type-object alternatives', {
    expect(42).to.be(Int | Str);
    expect('hi').to.be(Int | Str);
  }
}

describe 'expect with all junction', {
  it 'passes when actual smartmatches every member', {
    expect(5).to.be(Int & Numeric);
  }

  it 'fails when one constituent fails to match', {
    my $returned;
    my @new = induce({ $returned = expect('hi').to.be(Int & Str) });
    expect($returned).to.be-falsy;
    expect(@new.elems).to.be(1);
  }

  it 'is effectively unsatisfiable for distinct literal values', {
    my @new = induce({ expect(2).to.be(1 & 2 & 3) });
    expect(@new.elems).to.be(1);
  }

  it 'composes with .not', {
    expect('hi').to.not.be(Int & Numeric);
  }
}

describe 'expect with one junction', {
  it 'passes when exactly one alternative matches', {
    expect(2).to.be(1 ^ 2 ^ 3);
  }

  it 'fails when more than one alternative matches', {
    my @new = induce({ expect(2).to.be(2 ^ 2 ^ 3) });
    expect(@new.elems).to.be(1);
  }

  it 'fails when no alternative matches', {
    my @new = induce({ expect(5).to.be(1 ^ 2 ^ 3) });
    expect(@new.elems).to.be(1);
  }

  it 'composes with .not', {
    expect(5).to.not.be(1 ^ 2 ^ 3);
  }
}

describe 'expect with none junction', {
  it 'passes when actual matches no member', {
    expect(5).to.be(none(1, 2, 3));
  }

  it 'fails when actual matches any member', {
    my $returned;
    my @new = induce({ $returned = expect(2).to.be(none(1, 2, 3)) });
    expect($returned).to.be-falsy;
    expect(@new.elems).to.be(1);
  }

  it 'composes with .not when actual matches one member', {
    expect(2).to.not.be(none(1, 2, 3));
  }

  it 'fails negation when actual matches no member', {
    my @new = induce({ expect(5).to.not.be(none(1, 2, 3)) });
    expect(@new.elems).to.be(1);
    expect(@new[0].negated).to.be-truthy;
  }
}

describe 'junctions of subset types', {
  my subset Positive of Int where * > 0;

  it 'matches actual against an `all` junction of type and predicate', {
    expect(5).to.be(Int & Positive);
  }

  it 'fails when actual misses one constituent of an `all` junction', {
    my @new = induce({ expect(-1).to.be(Int & Positive) });
    expect(@new.elems).to.be(1);
  }

  it 'matches a value against an `any` junction of subset types', {
    my subset Even of Int where * %% 2;
    my subset Odd  of Int where * %% 2 == False;
    expect(3).to.be(Even | Odd);
  }
}

describe 'junction smartmatch returns Bool', {
  it 'collapses any-junction smartmatch to True for matching actual', {
    my $r = expect(2).to.be(1 | 2 | 3);
    expect($r).to.be-truthy;
    expect($r).to.be-a(Bool);
  }

  it 'collapses any-junction smartmatch to False for non-matching actual', {
    my @new = induce({
      my $r = expect(99).to.be(1 | 2 | 3);
      expect($r).to.be-falsy;
      expect($r).to.be-a(Bool);
    });
    expect(@new.elems).to.be(1);
  }
}
