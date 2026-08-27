use BDD::Behave;
use BDD::Behave::DryRun;
use BDD::Behave::Parallel::EventStream;
use BDD::Behave::SpecTree;

constant Suite         = BDD::Behave::SpecTree::Suite;
constant ExampleGroup  = BDD::Behave::SpecTree::ExampleGroup;
constant Example       = BDD::Behave::SpecTree::Example;
constant FilterOptions = BDD::Behave::DryRun::FilterOptions;

sub built-suite(Str $description = 'spec.raku', Str $file = '/abs/spec.raku' --> Suite) {
  my $suite = Suite.new(:$description, :file($file.IO), :line(1));
  my $group = ExampleGroup.new(:description('a group'), :file($file.IO), :line(5));
  $suite.add-child($group);

  $group.add-child(Example.new(
    :description('adds numbers'),
    :file($file.IO),
    :line(7),
    :block(sub { }),
  ));
  $group.add-child(Example.new(
    :description('subtracts numbers'),
    :file($file.IO),
    :line(11),
    :block(sub { }),
  ));

  $suite;
}

sub load-errors-of(%error --> Array) {
  my @errors;
  @errors.push(%error);
  @errors;
}

sub matching(@suites, *%filters --> List) {
  BDD::Behave::DryRun::matching-examples(@suites, FilterOptions.new(|%filters));
}

describe 'picking examples by a description pattern', {
  let(:suites, { [built-suite()] });

  it 'takes an example whose description holds the text', {
    expect(matching(suites(), :example-patterns(['adds'])).elems).to.be(1);
  }

  it 'takes no example when the text appears nowhere', {
    expect(matching(suites(), :example-patterns(['divides'])).elems).to.be(0);
  }

  it 'takes an example matching a pattern written as a regex', {
    expect(matching(suites(), :example-patterns(['/adds | multiplies/'])).elems)
      .to.be(1);
  }

  it 'takes no example when the regex matches nothing', {
    expect(matching(suites(), :example-patterns(['/divides \d+/'])).elems).to.be(0);
  }
}

describe 'picking examples by location', {
  let(:suites, { [built-suite()] });

  it 'takes the example declared at that line', {
    expect(matching(suites(), :only-locations(['/abs/spec.raku:7'])).elems).to.be(1);
  }

  it 'takes every example of a group declared at that line', {
    expect(matching(suites(), :only-locations(['/abs/spec.raku:5'])).elems).to.be(2);
  }

  it 'takes an example named by the file basename', {
    expect(matching(suites(), :only-locations(['spec.raku:7'])).elems).to.be(1);
  }

  it 'takes an example named by a trailing part of the path', {
    expect(matching(suites(), :only-locations(['abs/spec.raku:7'])).elems).to.be(1);
  }

  it 'takes no example for a line nothing was declared at', {
    expect(matching(suites(), :only-locations(['/abs/spec.raku:99'])).elems).to.be(0);
  }

  it 'takes no example for a location with no line at all', {
    expect(matching(suites(), :only-locations(['/abs/spec.raku'])).elems).to.be(0);
  }
}

describe 'rendering a dry run over several spec files', {
  let(:rendered, {
    BDD::Behave::DryRun::render-text(
      [built-suite('first.raku', '/abs/first.raku'),
       built-suite('second.raku', '/abs/second.raku')],
      FilterOptions.new,
    );
  });

  it 'heads each file with its name', {
    expect(rendered()).to.include('# first.raku');
  }

  it 'heads the second file too', {
    expect(rendered()).to.include('# second.raku');
  }
}

describe 'rendering a dry run as json', {
  let(:document, {
    parse-json-event(
      BDD::Behave::DryRun::render-json(
        [built-suite()],
        FilterOptions.new,
        :load-errors(load-errors-of(%( :file('/abs/broken.raku'), :message('boom') ))),
      ).lines.join,
    );
  });

  it 'counts the examples it would run', {
    expect(document()<count>).to.be(2);
  }

  it 'reports a spec file that failed to load', {
    expect(document(){'load-errors'}[0]<file>).to.eq('/abs/broken.raku');
  }

  it 'reports why that file failed', {
    expect(document(){'load-errors'}[0]<message>).to.eq('boom');
  }
}

describe 'serializing a node that is neither a group nor an example', {
  it 'writes nothing for it', {
    expect(BDD::Behave::DryRun::serialize-suite-node('not a node').elems).to.be(0);
  }
}
