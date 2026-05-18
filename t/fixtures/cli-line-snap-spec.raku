use BDD::Behave;

describe 'outer group', :order<defined>, {
  it 'alpha example', {
    my $x = 1;
    expect($x).to.eq(1);
  }

  it 'beta example', {
    expect(2).to.eq(2);
  }

  context 'inner group', {
    it 'gamma example', {
      my $y = 10;
      expect($y).to.eq(10);
    }

    it 'delta example', {
      expect(4).to.eq(4);
    }
  }

  it 'epsilon example', {
    expect(5).to.eq(5);
  }
}
