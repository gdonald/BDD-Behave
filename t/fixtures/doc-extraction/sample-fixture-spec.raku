use BDD::Behave;

describe 'Calculator', :order<defined>, {
  context 'addition', {
    it 'adds two positive numbers',  :tag<user-facing>, { expect(1 + 1).to.eq(2) }
    it 'adds a positive and zero',                       { expect(1 + 0).to.eq(1) }
    pending 'is not yet implemented',                    { Nil }
  }

  context 'subtraction', {
    it 'subtracts two positive numbers', :tag<internal>, { expect(3 - 1).to.eq(2) }
    xit 'is intentionally skipped',                      { Nil }
  }
}
