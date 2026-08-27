use BDD::Behave;
use BDD::Behave::Runner;
use BDD::Behave::SpecTree;
use Test::Output;

constant Suite        = BDD::Behave::SpecTree::Suite;
constant ExampleGroup = BDD::Behave::SpecTree::ExampleGroup;
constant Example      = BDD::Behave::SpecTree::Example;
constant Runner       = BDD::Behave::Runner::Runner;

# A runner writes to stdout as it goes, so every run below is driven with its
# output captured and only the result and the warnings read back.
sub run-suite($suite --> Hash) {
  my $result;
  my $errors = stderr-from({
    stdout-from({ $result = Runner.new(:format('progress')).run($suite) });
  });

  %( :$result, :$errors );
}

sub suite-with(&build --> Suite) {
  my $suite = Suite.create(:description('Synthetic'), :file('synthetic'.IO), :line(1));
  my $group = ExampleGroup.new(:description('a group'), :file('synthetic'.IO), :line(5));
  $suite.add-group($group);

  build($group);

  $suite;
}

sub passing-example(Str $description = 'an example', Int $line = 10 --> Example) {
  Example.new(:$description, :file('synthetic'.IO), :$line, :block({ True }));
}

describe 'an around-all hook that never runs its continuation', {
  let(:outcome, {
    run-suite(suite-with(-> $group {
      $group.add-example(passing-example());
      $group.add-example(passing-example('another example', 14));
      $group.add-hook('around-all', -> &continue { 'skipped on purpose' });
    }));
  });

  it 'counts every example of the group as skipped', {
    expect(outcome()<result>.skipped).to.be(2);
  }

  it 'runs none of them', {
    expect(outcome()<result>.passed).to.be(0);
  }
}

describe 'an around-all hook that fails', {
  let(:outcome, {
    run-suite(suite-with(-> $group {
      $group.add-example(passing-example());
      $group.add-hook('around-all', -> &continue { die 'around-all broke' });
    }));
  });

  it 'runs the examples of the group anyway', {
    expect(outcome()<result>.total).to.be(1);
  }
}

describe 'an around-each hook that fails after running the example', {
  let(:outcome, {
    run-suite(suite-with(-> $group {
      $group.add-example(passing-example());
      $group.add-hook('around-each', -> &continue { continue(); die 'around-each broke' });
    }));
  });

  it 'keeps the example that already ran', {
    expect(outcome()<result>.passed).to.be(1);
  }
}

describe 'an around-each hook that fails before running the example', {
  let(:outcome, {
    run-suite(suite-with(-> $group {
      $group.add-example(passing-example());
      $group.add-hook('around-each', -> &continue { die 'around-each broke early' });
    }));
  });

  it 'fails the example', {
    expect(outcome()<result>.failed).to.be(1);
  }
}

describe 'a before-each hook that fails', {
  let(:outcome, {
    run-suite(suite-with(-> $group {
      $group.add-example(passing-example());
      $group.add-hook('before-each', { die 'before-each broke' });
    }));
  });

  it 'still reaches the example', {
    expect(outcome()<result>.total).to.be(1);
  }
}

describe 'a before-all hook filtered to a tag no example carries', {
  let(:outcome, {
    run-suite(suite-with(-> $group {
      $group.add-example(passing-example());
      $group.add-hook(
        'before-all', { die 'this hook should not run' }, :include-tags(['nonexistent']),
      );
    }));
  });

  it 'still runs the example', {
    expect(outcome()<result>.passed).to.be(1);
  }
}

describe 'the way a runner matches an example against a location', {
  let(:runner, { Runner.new(:format('progress')) });

  it 'matches the same path and line', {
    expect(runner().location-matches-pattern('/abs/spec.raku:7', '/abs/spec.raku:7'))
      .to.be-truthy;
  }

  it 'matches a path written relative to the file', {
    expect(runner().location-matches-pattern('/abs/dir/spec.raku:7', 'dir/spec.raku:7'))
      .to.be-truthy;
  }

  it 'matches the file basename', {
    expect(runner().location-matches-pattern('/abs/spec.raku:7', 'spec.raku:7')).to.be-truthy;
  }

  it 'does not match another line of the same file', {
    expect(runner().location-matches-pattern('/abs/spec.raku:7', 'spec.raku:9')).to.be-falsy;
  }

  it 'does not match another file at the same line', {
    expect(runner().location-matches-pattern('/abs/spec.raku:7', 'other.raku:7')).to.be-falsy;
  }

  it 'does not match a pattern carrying no line', {
    expect(runner().location-matches-pattern('/abs/spec.raku:7', 'spec.raku')).to.be-falsy;
  }
}
