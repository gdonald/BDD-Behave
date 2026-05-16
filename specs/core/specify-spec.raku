use BDD::Behave;
use BDD::Behave::SpecRegistry;
use BDD::Behave::SpecTree;

constant ExampleGroup = BDD::Behave::SpecTree::ExampleGroup;

# Module-level counter so the body of the `specify` fixture can prove that
# the spec runner actually executed it.
my $body-ran-count = 0;

describe 'specify (file)', :order<defined>, {
  describe 'specify-spec fixture', {
    specify 'specify with description registers an example', {
      $body-ran-count++;
      expect(1).to.be(1);
    }

    specify 'specify with metadata', :tag<demo>, {
      expect(1).to.be(1);
    }

    specify {
      expect(1).to.be(1);
    }
  }

  sub find-fixture() {
    my $suite = registry().suites
      .first({ .file.basename eq 'specify-spec.raku' });
    for $suite.groups -> $g {
      return $g if $g.description eq 'specify-spec fixture';
      for $g.groups -> $inner {
        return $inner if $inner.description eq 'specify-spec fixture';
      }
    }
    Nil;
  }

  describe 'specify', {
  it 'is exported and registers examples like `it`', {
    my $fixture = find-fixture();
    my @descs   = $fixture.examples.map(*.description);
    expect(@descs).to.include('specify with description registers an example');
  }

  it 'forwards metadata (tags) to the underlying example', {
    my $fixture = find-fixture();
    my $example = $fixture.examples.first(*.description eq 'specify with metadata');
    expect($example.tags).to.include('demo');
  }

  it 'supports the block-only form (auto-description placeholder)', {
    my $fixture = find-fixture();
    my $auto    = $fixture.examples.first({
      .description.starts-with('example at specify-spec.raku:')
    });
    expect($auto.description).to.start-with('example at specify-spec.raku:');
  }

  it 'stores the block as a Callable for deferred execution', {
    my $fixture = find-fixture();
    expect($fixture.examples[0].block ~~ Callable).to.be-truthy;
  }

  it 'specify-registered example bodies run via the spec runner', {
    expect($body-ran-count).to.be-greater-than-or-equal-to(1);
  }
  }
}
