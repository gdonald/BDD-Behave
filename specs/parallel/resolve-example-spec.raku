use BDD::Behave;
use BDD::Behave::Parallel;
use BDD::Behave::SpecTree;

describe 'resolving a worker event whose id names no loaded example', {
  let(:example, {
    BDD::Behave::Parallel::resolve-example((), %(
      :id('/abs/spec.raku:9'), :description('checks totals'), :file('/abs/spec.raku'), :line(9),
    ));
  });

  it 'builds an example from the description in the event', {
    expect(example().description).to.eq('checks totals');
  }

  it 'builds an example from the line in the event', {
    expect(example().line).to.be(9);
  }
}

describe 'resolving a worker event whose id names a loaded example', {
  let(:suite, {
    BDD::Behave::SpecTree::Suite.create(:description('synthetic'), :file('/abs/spec.raku'.IO), :line(1));
  });

  let(:loaded, {
    BDD::Behave::SpecTree::Example.new(
      :description('example at spec.raku:9'), :file('/abs/spec.raku'.IO), :line(9), :block(sub { }),
    );
  });

  before-each {
    suite().add-child(loaded());
  }

  context 'when the event carries the description the worker derived', {
    let(:example, {
      BDD::Behave::Parallel::resolve-example((suite(),), %(
        :id('/abs/spec.raku:9'), :description('should eq 42'),
      ));
    });

    it 'renames the loaded example to the derived description', {
      expect(example().description).to.eq('should eq 42');
    }
  }

  context 'when the event carries no description', {
    let(:example, {
      BDD::Behave::Parallel::resolve-example((suite(),), %( :id('/abs/spec.raku:9') ));
    });

    it 'keeps the loaded example description', {
      expect(example().description).to.eq('example at spec.raku:9');
    }
  }
}
