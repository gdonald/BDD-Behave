use BDD::Behave;
use BDD::Behave::SpecRegistry;
use BDD::Behave::SpecTree;

constant SpecRegistry = BDD::Behave::SpecRegistry::SpecRegistry;
constant ExampleGroup = BDD::Behave::SpecTree::ExampleGroup;
constant Example      = BDD::Behave::SpecTree::Example;

sub built-registry(--> SpecRegistry) {
  my $registry = SpecRegistry.new;
  my $file = $*PROGRAM.absolute.IO;
  my $entry = $registry.entry-for($file);

  my $group = ExampleGroup.new(:description('math'), :file($file), :line(20));
  $entry.suite.add-group($group);

  my $fast = Example.new(
    :description('adds numbers'),
    :file($file), :line(22), :block(-> { }),
  );
  $fast.set-metadata(:areas(<db http>));
  $fast.set-metadata(:speed('fast'));
  $group.add-example($fast);

  my $slow = Example.new(
    :description('multiplies numbers'),
    :file($file), :line(25), :block(-> { }),
  );
  $slow.set-metadata(:areas(<http>));
  $slow.set-metadata(:speed('slow'));
  $group.add-example($slow);

  $registry;
}

describe 'a query result naming where its example lives', {
  it 'joins the file and line', {
    my $result = built-registry().all-examples[0];

    expect($result.location).to.eq("{$*PROGRAM.absolute}:22");
  }
}

describe 'querying examples by the file they live in', {
  let(:registry, { built-registry() });

  it 'takes them by the whole path', {
    expect(registry().query-examples(:file($*PROGRAM.absolute)).elems).to.be(2);
  }

  it 'takes them by the path as an IO object', {
    expect(registry().query-examples(:file($*PROGRAM.absolute.IO)).elems).to.be(2);
  }

  it 'takes them by the file basename', {
    expect(registry().query-examples(:file($*PROGRAM.basename)).elems).to.be(2);
  }

  it 'takes them by a trailing part of the path', {
    my $tail = $*PROGRAM.absolute.split('/')[*-2 .. *-1].join('/');

    expect(registry().query-examples(:file($tail)).elems).to.be(2);
  }

  it 'takes none from another file', {
    expect(registry().query-examples(:file('/elsewhere/other-spec.raku')).elems).to.be(0);
  }
}

describe 'querying examples by metadata', {
  let(:registry, { built-registry() });

  it 'takes an example carrying the value', {
    expect(registry().query-examples(:metadata({ speed => 'fast' })).elems).to.be(1);
  }

  it 'takes an example whose list holds the value', {
    expect(registry().query-examples(:metadata({ areas => 'db' })).elems).to.be(1);
  }

  it 'takes an example whose list is exactly the one asked for', {
    expect(registry().query-examples(:metadata({ areas => <db http> })).elems).to.be(1);
  }

  it 'takes no example whose list is a different length', {
    expect(registry().query-examples(:metadata({ areas => <db http mail> })).elems).to.be(0);
  }

  it 'takes no example whose list holds different values', {
    expect(registry().query-examples(:metadata({ areas => <db mail> })).elems).to.be(0);
  }

  it 'takes no example carrying nothing for the key', {
    expect(registry().query-examples(:metadata({ missing => 'x' })).elems).to.be(0);
  }
}

describe 'querying examples that exclude metadata', {
  let(:registry, { built-registry() });

  it 'drops an example carrying the value', {
    expect(registry().query-examples(:metadata-exclude({ speed => 'slow' })).elems).to.be(1);
  }

  it 'keeps every example when nothing carries the value', {
    expect(registry().query-examples(:metadata-exclude({ speed => 'glacial' })).elems).to.be(2);
  }
}

describe 'the group a spec file is currently inside', {
  let(:registry, { SpecRegistry.new });
  let(:file, { $*PROGRAM.absolute.IO });

  it 'is nothing before any group opens', {
    registry().entry-for(file());

    expect(registry().current-group-for(file())).to.be(Nil);
  }

  it 'is the group that opened last', {
    my $entry = registry().entry-for(file());
    my $group = ExampleGroup.new(:description('math'), :file(file()), :line(20));
    $entry.stack.push($group);

    expect(registry().current-group-for(file()).description).to.eq('math');
  }
}

describe 'the suites the process-wide registry holds', {
  it 'reports one suite per spec file that was loaded', {
    expect(suites().elems > 0).to.be-truthy;
  }

  it 'reports the same suites the registry holds', {
    expect(suites().elems).to.be(registry().suites.elems);
  }
}
