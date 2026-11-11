use BDD::Behave;
use lib $?FILE.IO.parent.Str;
use UnreportedLines;

describe 'UnreportedLines', :order<defined>, {
  it 'returns from the CATCH block', {
    expect(guarded()).to.eq('caught');
  }

  it 'builds a hash from a multi-line literal', {
    expect(build(5)<name>).to.eq('Acme');
  }

  it 'classifies a negative number', {
    expect(classify(-1)).to.eq('negative');
  }

  it 'classifies zero in the elsif branch', {
    expect(classify(0)).to.eq('zero');
  }

  it 'classifies a positive number', {
    expect(classify(1)).to.eq('positive');
  }

  it 'builds a hash from colon pairs', {
    expect(rules()<blank>).to.be-falsy;
  }

  it 'refuses an empty name', {
    expect(refuse-empty('')).to.eq('a name is required');
  }

  it 'returns a given name', {
    expect(refuse-empty('Acme')).to.eq('Acme');
  }

  it 'counts down to zero', {
    expect(count-down(3)).to.eq(0);
  }
}
