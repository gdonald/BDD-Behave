use BDD::Behave;
use BDD::Behave::SpecTree;

constant Suite        = BDD::Behave::SpecTree::Suite;
constant ExampleGroup = BDD::Behave::SpecTree::ExampleGroup;
constant Example      = BDD::Behave::SpecTree::Example;

describe 'Suite (top-level container)', {
  it 'is created via .create with sensible defaults', {
    my $suite = Suite.create(:file('specs/example.raku'));

    expect($suite.is-root).to.be(True);
    expect($suite.description).to.be('suite');
    expect($suite.depth).to.be(0);
    expect($suite.children.elems).to.be(0);
  }

  it 'accepts an explicit description', {
    my $suite = Suite.create(:description('custom'), :file('specs/example.raku'));
    expect($suite.description).to.be('custom');
  }
}

describe 'ExampleGroup parenting and depth', {
  it 'links a group to its parent suite when added', {
    my $suite = Suite.create(:file('specs/example.raku'));
    my $group = ExampleGroup.new(:description('math'), :file('specs/example.raku'), :line(10));
    $suite.add-group($group);

    expect($suite.groups.elems).to.be(1);
    expect($group.parent).to.be($suite);
    expect($group.depth).to.be(1);
  }

  it 'increments depth one per nesting level', {
    my $suite = Suite.create(:file('specs/example.raku'));
    my $outer = ExampleGroup.new(:description('outer'), :file('specs/example.raku'), :line(1));
    my $inner = ExampleGroup.new(:description('inner'), :file('specs/example.raku'), :line(2));
    $suite.add-group($outer);
    $outer.add-group($inner);

    expect($outer.depth).to.be(1);
    expect($inner.depth).to.be(2);
  }
}

describe 'Example linkage and ancestry', {
  it 'records the group as parent and exposes ancestry walking suite/group/example', {
    my $suite   = Suite.create(:file('specs/example.raku'));
    my $group   = ExampleGroup.new(:description('math'), :file('specs/example.raku'), :line(10));
    my $example = Example.new(
      :description('adds numbers'),
      :file('specs/example.raku'),
      :line(12),
      :block(-> :$value { $value + 1 }),
    );
    $suite.add-group($group);
    $group.add-example($example);

    expect($group.examples.elems).to.be(1);
    expect($example.ancestry».description.list.Array)
      .to.be(['suite', 'math', 'adds numbers']);
  }

  it 'executes the stored block and forwards named args', {
    my $example = Example.new(
      :description('takes a value'),
      :file('specs/example.raku'),
      :line(1),
      :block(-> :$value { $value + 1 }),
    );

    expect($example.execute(:value(41))).to.be(42);
  }
}

describe 'Pending markers and metadata', {
  it 'starts not pending', {
    my $example = Example.new(
      :description('x'),
      :file('specs/example.raku'),
      :line(1),
      :block({ True }),
    );
    expect($example.pending ?? 1 !! 0).to.be(0);
  }

  it 'records pending state and a stored reason after mark-pending', {
    my $example = Example.new(
      :description('x'),
      :file('specs/example.raku'),
      :line(1),
      :block({ True }),
    );
    $example.mark-pending(:reason('wip'));

    expect($example.pending).to.be(True);
    expect($example.get-metadata('pending-reason')).to.be('wip');
  }
}

describe 'Hook registration on a group', {
  it 'returns the registered block from add-hook and stores it under the phase', {
    my $group = ExampleGroup.new(
      :description('hooks'),
      :file('specs/example.raku'),
      :line(1),
    );
    my $marker = 'sentinel';
    my $before-each = $group.add-hook('before-each', -> { $marker });
    my $after-all   = $group.add-hook('after-all',   -> { $marker });

    expect($group.hooks('before-each').elems).to.be(1);
    expect($group.hooks('after-all').elems).to.be(1);
    expect($group.hooks('before-each')[0] === $before-each ?? 1 !! 0).to.be(1);
    expect($group.hooks('after-all')[0]   === $after-all   ?? 1 !! 0).to.be(1);
  }

  it 'returns an empty list for phases with no registered hooks', {
    my $group = ExampleGroup.new(
      :description('empty'),
      :file('specs/example.raku'),
      :line(1),
    );
    expect($group.hooks('before-each').elems).to.be(0);
    expect($group.hooks('after-all').elems).to.be(0);
  }
}

describe 'Suite let storage', {
  it 'records lets added to the suite via add-let', {
    use BDD::Behave::LetRuntime;
    my $def = BDD::Behave::LetRuntime::LetDefinition.new(
      :name('size'),
      :block({ 3 }),
    );

    my $suite = Suite.create(:file('specs/example.raku'));
    $suite.add-let($def);

    expect($suite.let-definitions.elems).to.be(1);
    expect($suite.let-definitions[0].name).to.be('size');
  }
}
