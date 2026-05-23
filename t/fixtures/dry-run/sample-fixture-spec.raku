use BDD::Behave;

describe 'Cart', :order<defined>, {
  context 'adding items', {
    it 'increments the count',     :tag<fast>,  { expect(1 + 1).to.eq(2) }
    it 'updates the total price',                { expect(2 + 3).to.eq(5) }
    pending 'persists across reloads',           { Nil }
  }

  context 'removing items', {
    it 'decrements the count', :tag<slow>, :type<integration>, { expect(2 - 1).to.eq(1) }
    xit 'is intentionally skipped',                              { Nil }
  }
}
