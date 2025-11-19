
use BDD::Behave;

let(:foo, { 42 });

describe 'this spec', {
  it 'passes', {
    expect(:foo).to.be(42);
  }

  it 'fails on the next line', {
    let(:foo, { 41 });

    expect(:foo).to.be(42);
  }
}

describe 'another spec', {
  let(:foo, { 17 });

  it 'passes', {
    expect(:foo).to.be(17);
  }

  it 'this final spec fails on the next line', {
    let(:foo, { 13 });
    expect(:foo).to.be(17);
  }
}
