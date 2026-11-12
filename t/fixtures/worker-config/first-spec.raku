use BDD::Behave;

describe 'first worker config fixture', {
  it 'runs a fast example', :tag<fast>, { expect(1).to.be(1) }
}
