use BDD::Behave;

sub bucket-a-helper(Int $x --> Int) {
  my $y = $x + 1;
  $y * 2;
}

sub bucket-b-helper(Int $x --> Int) {
  my $z = $x - 1;
  $z * 3;
}

describe 'parallel coverage bucket A', :order<defined>, {
  it 'computes A1', {
    expect(bucket-a-helper(2)).to.be(6);
  }

  it 'computes A2', {
    expect(bucket-a-helper(4)).to.be(10);
  }
}

describe 'parallel coverage bucket B', :order<defined>, {
  it 'computes B1', {
    expect(bucket-b-helper(5)).to.be(12);
  }

  it 'computes B2', {
    expect(bucket-b-helper(7)).to.be(18);
  }
}
