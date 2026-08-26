use BDD::Behave;
use BDD::Behave::SpecTree;
use BDD::Behave::SpecTree::Core;

constant Suite        = BDD::Behave::SpecTree::Suite;
constant ExampleGroup = BDD::Behave::SpecTree::ExampleGroup;
constant Example      = BDD::Behave::SpecTree::Example;
constant SpecNode     = BDD::Behave::SpecTree::Core::SpecNode;

describe 'the ancestry of a spec node', {
  let(:suite, { Suite.create(:file('specs/example.raku')) });

  let(:group, {
    ExampleGroup.new(:description('math'), :file('specs/example.raku'), :line(10));
  });

  let(:example, {
    Example.new(
      :description('adds numbers'),
      :file('specs/example.raku'),
      :line(12),
      :block(sub { }),
    );
  });

  context 'given a node attached to a suite through a group', {
    before-each {
      suite().add-group(group());
      group().add-example(example());
    }

    it 'walks from the suite down to the node', {
      expect(example().ancestry».description.join(','))
        .to.eq('suite,math,adds numbers');
    }

    it 'yields spec nodes rather than a nested list', {
      expect(example().ancestry.all ~~ SpecNode).to.be-truthy;
    }

    it 'returns the same walk when asked twice', {
      example().ancestry;

      expect(example().ancestry».description.join(','))
        .to.eq('suite,math,adds numbers');
    }
  }

  context 'given a group attached to a suite after its own ancestry was read', {
    before-each {
      group().add-example(example());
      example().ancestry;
      suite().add-group(group());
    }

    it 'walks through the suite the group was attached to', {
      expect(example().ancestry».description.join(','))
        .to.eq('suite,math,adds numbers');
    }

    it 'counts the suite in the depth of the node', {
      expect(example().depth).to.be(2);
    }

    it 'names the suite as the root of the node', {
      expect(example().root.description).to.eq('suite');
    }
  }
}
