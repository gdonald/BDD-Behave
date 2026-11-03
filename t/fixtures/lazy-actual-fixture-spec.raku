use BDD::Behave;

describe 'a list built by a map that calls a let', {
  let(:wanted, { 'b' });

  it 'reports its values when the comparison fails', {
    expect(<a c>.map({ $_ eq wanted() }).List).to.eq((True, True));
  }
}
