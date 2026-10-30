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
}
