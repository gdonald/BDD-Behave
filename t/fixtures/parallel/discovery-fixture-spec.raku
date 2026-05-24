use BDD::Behave;

it 'top-level example outside any describe', :tag<smoke>, { expect(True).to.be(True) }

describe 'Cart', :order<defined>, :tag<unit>, {
  context 'adding items', :type<integration>, {
    it 'increments the count', :tag<fast>,    { expect(1 + 1).to.eq(2) }
    it 'updates the total price',             { expect(2 + 3).to.eq(5) }
    pending 'persists across reloads',        { Nil }
  }

  context 'removing items', {
    it 'decrements the count', :tag<slow>, :type<integration>, { expect(2 - 1).to.eq(1) }
    xit 'is intentionally skipped',                              { Nil }
  }

  describe 'with focused branch', {
    fit 'is the focused one',                 { expect(1).to.be(1) }
    it 'normal sibling that is dimmed in focus mode', { expect(1).to.be(1) }
  }
}
