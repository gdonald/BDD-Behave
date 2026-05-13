use BDD::Behave;

describe 'xit skips a single example', {
  it 'this example runs', {
    expect(1 + 1).to.be(2);
  }

  xit 'this example is skipped (body never runs)', {
    expect(False).to.be-truthy;
  }

  it 'this example also runs', {
    expect('hi'.uc).to.be('HI');
  }
}

xdescribe 'xdescribe skips an entire group', {
  it 'never runs',         { expect(1).to.be(2); }
  it 'never runs either',  { expect(2).to.be(3); }

  context 'including nested children', {
    it 'never runs as well', { expect(3).to.be(4); }
  }
}

describe 'xcontext skips a single context block', {
  it 'this one runs', {
    expect([1, 2, 3].elems).to.be(3);
  }

  xcontext 'inside an xcontext', {
    it 'never runs',        { expect(False).to.be-truthy; }
    it 'also never runs',   { expect(False).to.be-truthy; }
  }
}
