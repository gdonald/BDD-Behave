use BDD::Behave;

describe 'metadata filter fixture', :order<defined>, {
  it 'unit one',  :type<unit>,        { expect(1).to.eq(1) }
  it 'unit two',  :type<unit>,        { expect(2).to.eq(2) }
  it 'integ one', :type<integration>, { expect(3).to.eq(3) }
}
