
use BDD::Behave;

describe -> 'foo bar' {
  let(:number) => { 42 };

  context -> 'bar baz' {
    it -> 'baz foo' {
      expect(42).to.be(42);
      expect(:number).to.be(42);
      expect(42).to.be(:number);
    }
  }

  context -> 'baz foo' {
    let(:number) => { '42' };

    it -> 'final foo bar has 3 expects' {
      expect('42').to.be('42');
      expect(:number).to.be('42');
      expect('42').to.be(:number);
    }
  }
}
