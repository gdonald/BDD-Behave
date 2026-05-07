use BDD::Behave;

describe 'fit focuses one example', {
  it  'plain example, filtered out by focus mode',  { expect(1).to.be(2); }
  fit 'focused example runs',                       { expect(2 * 2).to.be(4); }
  it  'another plain example, also filtered out',   { expect(1).to.be(2); }
}

fdescribe 'fdescribe focuses an entire group', {
  it 'every example here runs', {
    expect('hello'.chars).to.be(5);
  }

  it 'including this one', {
    expect((1, 2, 3).sum).to.be(6);
  }

  context 'and nested groups inside an fdescribe', {
    it 'inherit the focus', {
      expect('Behave'.lc).to.be('behave');
    }
  }
}

describe 'sibling group filtered out by focus mode', {
  it 'this never displays because focus mode is on', {
    expect(False).to.be(True);
  }
}

fdescribe 'focus + skip combined', {
  it  'focused and runs', { expect(7 + 1).to.be(8); }
  xit 'skipped, body never executes', { expect(False).to.be(True); }
}
