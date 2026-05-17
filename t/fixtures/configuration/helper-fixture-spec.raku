use BDD::Behave;

describe 'config helper fixture', :order<defined>, {
  it 'reads from $*BEHAVE-HELPERS', {
    expect($*BEHAVE-HELPERS<Greet>.hello).to.eq('hello');
  }
}
