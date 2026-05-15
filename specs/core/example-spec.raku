use BDD::Behave;
use BDD::Behave::SpecRegistry;
use BDD::Behave::SpecTree;

constant ExampleGroup = BDD::Behave::SpecTree::ExampleGroup;

my $body-ran-count = 0;

describe 'example-spec fixture', {
  example 'example with description registers an example', {
    $body-ran-count++;
    expect(1).to.be(1);
  }

  example 'example with metadata', :tag<demo>, {
    expect(1).to.be(1);
  }

  example {
    expect(1).to.be(1);
  }
}

sub find-fixture() {
  registry().suites
    .first({ .file.basename eq 'example-spec.raku' })
    .groups.first(*.description eq 'example-spec fixture');
}

describe 'example', {
  it 'is exported and registers examples like `it`', {
    my $fixture = find-fixture();
    my @descs   = $fixture.examples.map(*.description);
    expect(@descs).to.include('example with description registers an example');
  }

  it 'forwards metadata (tags) to the underlying example', {
    my $fixture = find-fixture();
    my $ex = $fixture.examples.first(*.description eq 'example with metadata');
    expect($ex.tags).to.include('demo');
  }

  it 'supports the block-only form (auto-description placeholder)', {
    my $fixture = find-fixture();
    my $auto    = $fixture.examples.first({
      .description.starts-with('example at example-spec.raku:')
    });
    expect($auto.description).to.start-with('example at example-spec.raku:');
  }

  it 'stores the block as a Callable for deferred execution', {
    my $fixture = find-fixture();
    expect($fixture.examples[0].block ~~ Callable).to.be-truthy;
  }

  it 'example-registered example bodies run via the spec runner', {
    expect($body-ran-count).to.be-greater-than-or-equal-to(1);
  }
}
