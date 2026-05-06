use BDD::Behave;

shared-examples 'a counter', {
  it 'starts at zero', {
    expect(:start).to.be(0);
  }

  it 'has an increment step', {
    expect(:step).to.be(1);
  }
};

shared-examples 'a sized collection', -> $expected {
  it "reports its size as $expected", {
    expect($*LET-RUNTIME.value('size')).to.be($expected);
  }
};

shared-examples 'a greeter', -> $name {
  it "greets $name", {
    expect("hello, $name").to.be("hello, $name");
  }
};

describe 'include-examples merges examples into the current group', {
  let(:start, { 0 });
  let(:step,  { 1 });

  include-examples 'a counter';
}

describe 'it-behaves-like wraps examples in a nested group', {
  let(:start, { 0 });
  let(:step,  { 1 });

  it-behaves-like 'a counter';
}

describe 'parameterized shared examples', {
  let(:size, { 3 });

  it-behaves-like 'a sized collection', 3;
}

describe 'multiple shared examples in one describe', {
  let(:start, { 0 });
  let(:step,  { 1 });

  it-behaves-like 'a counter';
  it-behaves-like 'a greeter', 'world';
}
