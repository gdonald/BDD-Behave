use BDD::Behave;
use BDD::Behave::DryRun;
use BDD::Behave::Formatter::Tree;
use BDD::Behave::Parallel::Distribution;
use BDD::Behave::Runner;
use BDD::Behave::SpecRegistry;
use BDD::Behave::SpecTree;

constant Suite        = BDD::Behave::SpecTree::Suite;
constant Example      = BDD::Behave::SpecTree::Example;
constant Runner       = BDD::Behave::Runner::Runner;
constant SpecRegistry = BDD::Behave::SpecRegistry::SpecRegistry;

sub example-at(Int $occurrence, Bool :$shares-line = $occurrence > 1 --> Example) {
  Example.new(
    :description('an example'), :file('/abs/spec.raku'.IO), :line(12),
    :$occurrence, :$shares-line, :block(sub { }),
  );
}

describe 'the id of a node alone on its line', {
  let(:example, { example-at(1) });

  it 'is the file and line', {
    expect(example().node-id).to.eq('/abs/spec.raku:12');
  }

  it 'matches a bare line', {
    expect(example().matches-line('12')).to.be-truthy;
  }

  it 'matches its occurrence on the line', {
    expect(example().matches-line('12[1]')).to.be-truthy;
  }

  it 'does not match another line', {
    expect(example().matches-line('13')).to.be-falsy;
  }
}

describe 'the id of the first node on a shared line', {
  let(:example, { example-at(1, :shares-line) });

  it 'adds the occurrence to the file and line', {
    expect(example().node-id).to.eq('/abs/spec.raku:12[1]');
  }

  it 'does not match another occurrence on the line', {
    expect(example().matches-line('12[2]')).to.be-falsy;
  }
}

describe 'the id of a later node on a shared line', {
  let(:example, { example-at(2) });

  it 'adds the occurrence to the file and line', {
    expect(example().node-id).to.eq('/abs/spec.raku:12[2]');
  }

  it 'matches a bare line', {
    expect(example().matches-line('12')).to.be-truthy;
  }

  it 'matches its own occurrence on the line', {
    expect(example().matches-line('12[2]')).to.be-truthy;
  }
}

describe 'the occurrences the registry assigns', {
  let(:group, {
    my $registry = SpecRegistry.new;
    my $file = '/abs/loop-spec.raku'.IO;

    $registry.register-group(:description('routes'), :$file, :line(3), :block({
      for ^3 {
        $registry.register-example(:description("route $_"), :$file, :line(3), :block(sub { }));
      }
    }));
    $registry.suites.head.children.head;
  });

  it 'gives each example on one line its own id', {
    expect(group().children.map(*.node-id).List)
      .to.eq(('/abs/loop-spec.raku:3[2]', '/abs/loop-spec.raku:3[3]', '/abs/loop-spec.raku:3[4]'));
  }

  it 'counts the group on the line together with its examples', {
    expect(group().node-id).to.eq('/abs/loop-spec.raku:3[1]');
  }
}

describe 'a node registered after its file has loaded', {
  let(:registry, {
    my $registry = SpecRegistry.new;
    my $file = '/abs/helper-spec.raku'.IO;

    $registry.register-group(:description('loaded'), :$file, :line(3), :block(sub { }));
    $registry.finish-loading($file);
    $registry.register-group(:description('built while running'), :$file, :line(3), :block(sub { }));
    $registry;
  });

  it 'leaves the id of the node loaded at the same line unchanged', {
    expect(registry().suites.head.children.head.node-id).to.eq('/abs/helper-spec.raku:3');
  }

  it 'gets an id of its own', {
    expect(registry().suites.head.children[1].node-id).to.eq('/abs/helper-spec.raku:3[2]');
  }
}

describe 'a location that names an occurrence', {
  let(:runner, {
    Runner.new(:formatter(BDD::Behave::Formatter::Tree.new), :only-locations(['/abs/spec.raku:12[2]']));
  });

  it 'selects the example with that occurrence', {
    expect(runner().location-matches(example-at(2))).to.be-truthy;
  }

  it 'leaves out the other examples on the line', {
    expect(runner().location-matches(example-at(1, :shares-line))).to.be-falsy;
  }
}

describe 'a dry run tree node', {
  let(:node, { BDD::Behave::DryRun::serialize-suite-node(example-at(3)) });

  it 'carries the occurrence of its node', {
    expect(node()<occurrence>).to.be(3);
  }

  it 'carries whether its node shares its line', {
    expect(node()<shares-line>).to.be-truthy;
  }
}

describe 'parallel buckets for top-level examples on one line', {
  let(:buckets, {
    my $suite = Suite.new(:description('spec.raku'), :file('/abs/spec.raku'.IO), :line(1));
    $suite.add-child(example-at($_, :shares-line)) for 1..2;

    collect-buckets($suite);
  });

  it 'gives each bucket its own id', {
    expect(buckets().map(*.id).List).to.eq(('/abs/spec.raku#ex:12[1]', '/abs/spec.raku#ex:12[2]'));
  }

  it 'sends each worker the location of its own example', {
    expect(buckets().map(*.locations.head).List).to.eq(('/abs/spec.raku:12[1]', '/abs/spec.raku:12[2]'));
  }
}
