use BDD::Behave;
use lib $?FILE.IO.parent.Str;
use SampleLib;

describe 'SampleLib', :order<defined>, {
  it 'greets a known name', {
    expect(greet('alice')).to.be('hello alice');
  }

  it 'adds two numbers', {
    expect(add(2, 3)).to.be(5);
  }
}
