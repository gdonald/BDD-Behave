use BDD::Behave;
use BDD::Behave::Callsite;

describe 'BDD::Behave::Callsite::is-behave-source', {
  it 'recognizes a module under lib/BDD/Behave in a checkout', {
    expect(is-behave-source('/home/dev/BDD-Behave/lib/BDD/Behave/DSL.rakumod')).to.be-truthy;
  }

  it 'recognizes the top-level module in a checkout', {
    expect(is-behave-source('lib/BDD/Behave.rakumod')).to.be-truthy;
  }

  it 'recognizes an installed BDD::Behave submodule', {
    expect(is-behave-source('site#sources/FCA2F770896E4A5DC9E4158B571C80EB2BCC8ACE (BDD::Behave::DSL)')).to.be-truthy;
  }

  it 'recognizes the installed top-level BDD::Behave module', {
    expect(is-behave-source('site#sources/0A1B2C3D4E5F60718293A4B5C6D7E8F901234567 (BDD::Behave)')).to.be-truthy;
  }

  it 'rejects an installed module from another distribution', {
    expect(is-behave-source('site#sources/0A1B2C3D4E5F60718293A4B5C6D7E8F901234567 (MVC::Keayl::CLI)')).to.be-falsy;
  }

  it 'rejects an installed module whose name only starts with BDD::Behave', {
    expect(is-behave-source('site#sources/0A1B2C3D4E5F60718293A4B5C6D7E8F901234567 (BDD::Behaviour)')).to.be-falsy;
  }

  it 'rejects a spec file', {
    expect(is-behave-source('/home/dev/crm/specs/users-spec.raku')).to.be-falsy;
  }

  it 'rejects an undefined file', {
    expect(is-behave-source(Str)).to.be-falsy;
  }
}

describe 'BDD::Behave::Callsite::user-frame', {
  it 'returns the frame of the spec that called into behave', {
    expect(user-frame().file.IO.basename).to.be('callsite-spec.raku');
  }
}

describe 'the location of an is-expected failure', {
  subject({ 1 });

  context 'when is-expected fails', {
    let(:failure-line, { $?LINE + 1 });
    let(:failure, { capture-failures({ is-expected.to.be(2) }).head });

    it 'records the spec file', {
      expect(failure.file.IO.basename).to.be('callsite-spec.raku');
    }

    it 'records the line of the is-expected call', {
      expect(failure.line).to.be(failure-line);
    }
  }
}
