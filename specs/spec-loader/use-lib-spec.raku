use lib 'lib';
use BDD::Behave;
use BDD::Behave::SpecLoader;

describe 'BDD::Behave::SpecLoader::wrap-source', {
  context 'when the source has no `use lib` directives', {
    it 'wraps the source unchanged in a module', {
      my $wrapped = BDD::Behave::SpecLoader::wrap-source('say 42', 'TestIso');

      expect($wrapped).to.be("module TestIso \{ say 42\n}");
    }
  }

  context 'when a top-level `use lib` is present', {
    it 'lifts the directive before the module wrapper', {
      my $code    = "use lib 'lib';\nsay 42";
      my $wrapped = BDD::Behave::SpecLoader::wrap-source($code, 'TestIso');

      expect($wrapped.starts-with(q{use lib 'lib'; module TestIso })).to.be-truthy;
    }

    it 'leaves no `use lib` inside the module wrapper', {
      my $code    = "use lib 'lib';\nsay 42";
      my $wrapped = BDD::Behave::SpecLoader::wrap-source($code, 'TestIso');

      expect($wrapped.contains("module TestIso \{ use lib")).to.be-falsy;
    }
  }

  context 'when the `use lib` is indented', {
    it 'still lifts it before the module wrapper', {
      my $code    = "  use lib 'lib';\nsay 42";
      my $wrapped = BDD::Behave::SpecLoader::wrap-source($code, 'TestIso');

      expect($wrapped.starts-with(q{  use lib 'lib'; module TestIso })).to.be-truthy;
    }
  }

  context 'when multiple `use lib` directives are present', {
    it 'lifts all of them in original order', {
      my $code    = "use lib 'lib';\nuse lib 'other';\nsay 42";
      my $wrapped = BDD::Behave::SpecLoader::wrap-source($code, 'TestIso');

      expect($wrapped.starts-with(q{use lib 'lib'; use lib 'other'; module TestIso })).to.be-truthy;
    }
  }

  context 'when the `use lib` appears past the first line', {
    it 'preserves line numbers of body lines that follow it', {
      my $code    = "use v6.d;\nuse lib 'lib';\nsay 42";
      my $wrapped = BDD::Behave::SpecLoader::wrap-source($code, 'TestIso');

      expect($wrapped.lines[2]).to.be('say 42');
    }
  }
}

describe 'a spec file with `use lib` at file scope', {
  it 'loads cleanly through SpecLoader (this very file proves it)', {
    expect(True).to.be-truthy;
  }
}
