use BDD::Behave;

describe 'benchmark-fixture', :order<defined>, {
  it 'measures a sum', {
    my $r = benchmark 'sum', :iterations(3), { (1..100).sum };
    expect($r.iterations).to.be(3);
  }

  it 'measures two labeled calls', {
    benchmark 'a', :iterations(2), { 1 + 1 };
    benchmark 'b', :iterations(2), { 2 * 2 };
  }

  it 'has no benchmark', {
    expect(1).to.be(1);
  }
}
