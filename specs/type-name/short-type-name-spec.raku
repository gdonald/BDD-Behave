use BDD::Behave;
use BDD::Behave::TypeName;

describe 'BDD::Behave::TypeName::short-type-name', {
  context 'when the type was declared inside a spec (GLOBAL:: prefix)', {
    it 'strips GLOBAL:: from a simple name', {
      my class TN-Simple { }

      expect(short-type-name(TN-Simple)).to.be('TN-Simple');
    }

    it 'strips GLOBAL:: from a compound name, preserving the rest', {
      my class X::TN::Compound { }

      expect(short-type-name(X::TN::Compound)).to.be('X::TN::Compound');
    }
  }

  context 'when the type has no GLOBAL:: prefix', {
    it 'returns the name unchanged', {
      expect(short-type-name(Int)).to.be('Int');
    }

    it 'leaves a package-qualified name from outside spec scope intact', {
      expect(short-type-name(IO::Path)).to.be('IO::Path');
    }
  }
}
