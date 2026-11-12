use BDD::Behave;

describe 'second worker config fixture', {
  it 'runs a slow example', :tag<slow>, { expect(2).to.be(2) }
}
