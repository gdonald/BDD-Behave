use BDD::Behave;
use BDD::Behave::SpecTree;

constant Suite        = BDD::Behave::SpecTree::Suite;
constant ExampleGroup = BDD::Behave::SpecTree::ExampleGroup;
constant Example      = BDD::Behave::SpecTree::Example;
constant Hook         = BDD::Behave::SpecTree::Hook;

describe 'what a spec node reports about itself', {
  let(:example, {
    Example.new(
      :description('an example'),
      :file('/abs/spec.raku'.IO),
      :line(12),
      :block(sub { }),
      :metadata({ tags => ['slow', 'database'] }),
    );
  });

  it 'names the file and line it was declared at', {
    expect(example().location).to.eq('/abs/spec.raku:12');
  }

  it 'reports a tag it carries', {
    expect(example().has-tag('slow')).to.be-truthy;
  }

  it 'does not report a tag it does not carry', {
    expect(example().has-tag('fast')).to.be-falsy;
  }
}

describe 'the tags a spec node inherits', {
  let(:example, {
    my $suite = Suite.new(:description('spec.raku'), :file('/abs/spec.raku'.IO), :line(1));
    my $group = ExampleGroup.new(
      :description('a group'),
      :file('/abs/spec.raku'.IO),
      :line(5),
      :metadata({ tags => ['integration'] }),
    );
    my $ex = Example.new(
      :description('an example'),
      :file('/abs/spec.raku'.IO),
      :line(7),
      :block(sub { }),
      :metadata({ tags => ['slow'] }),
    );

    $suite.add-child($group);
    $group.add-child($ex);
    $ex;
  });

  it 'reports a tag of its own', {
    expect(example().has-effective-tag('slow')).to.be-truthy;
  }

  it 'reports a tag from the group above it', {
    expect(example().has-effective-tag('integration')).to.be-truthy;
  }

  it 'does not report a tag nothing in the ancestry carries', {
    expect(example().has-effective-tag('fast')).to.be-falsy;
  }
}

describe 'a hook filtered by metadata', {
  sub node-with(%metadata) {
    Example.new(
      :description('an example'),
      :file('/abs/spec.raku'.IO),
      :line(7),
      :block(sub { }),
      :metadata(%metadata),
    );
  }

  sub hook-wanting(%meta) {
    Hook.new(:callback(sub { }), :%meta);
  }

  context 'given a single value the node carries', {
    it 'matches', {
      expect(hook-wanting({ area => 'db' }).matches(node-with({ area => 'db' })))
        .to.be-truthy;
    }

    it 'does not match a node carrying another value', {
      expect(hook-wanting({ area => 'db' }).matches(node-with({ area => 'http' })))
        .to.be-falsy;
    }

    it 'does not match a node carrying nothing for the key', {
      expect(hook-wanting({ area => 'db' }).matches(node-with({ }))).to.be-falsy;
    }
  }

  context 'given a single value against a node carrying a list', {
    it 'matches when the list holds it', {
      expect(hook-wanting({ area => 'db' }).matches(node-with({ area => ['db', 'http'] })))
        .to.be-truthy;
    }

    it 'does not match when the list does not hold it', {
      expect(hook-wanting({ area => 'db' }).matches(node-with({ area => ['http'] })))
        .to.be-falsy;
    }
  }

  context 'given a list of values', {
    it 'matches a node carrying all of them', {
      expect(
        hook-wanting({ area => ['db', 'http'] }).matches(node-with({ area => ['db', 'http'] })),
      ).to.be-truthy;
    }

    it 'does not match a node carrying only some of them', {
      expect(hook-wanting({ area => ['db', 'http'] }).matches(node-with({ area => ['db'] })))
        .to.be-falsy;
    }

    it 'matches a node carrying the single value the list asks for', {
      expect(hook-wanting({ area => ['db'] }).matches(node-with({ area => 'db' })))
        .to.be-truthy;
    }
  }

  context 'given no filter at all', {
    it 'matches any node', {
      expect(Hook.new(:callback(sub { })).matches(node-with({ }))).to.be-truthy;
    }
  }
}
