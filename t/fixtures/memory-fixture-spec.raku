use BDD::Behave;

describe 'memory-fixture', :order<defined>, {
  it 'a allocates a chunk', {
    my @data = (1 .. 50_000).map(*.Str);
    expect(@data.elems).to.be(50_000);
  }

  it 'b allocates a bigger chunk', {
    my @data = (1 .. 200_000).map(*.Str);
    expect(@data.elems).to.be(200_000);
  }

  it 'c small example', {
    expect(1 + 1).to.be(2);
  }
}
