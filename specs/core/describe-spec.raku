use BDD::Behave;
use BDD::Behave::SpecRegistry;
use BDD::Behave::SpecTree;

constant Suite        = BDD::Behave::SpecTree::Suite;
constant ExampleGroup = BDD::Behave::SpecTree::ExampleGroup;

# Fixture: registered as part of this spec file's registration phase.
# Body never runs because no example here has a passing case for fdescribe;
# we only inspect its registered structure from the test describe below.
my $fixture-ran = False;

describe 'describe-spec fixture', {
  context 'describe-spec fixture inner', {
    it 'fixture example', {
      $fixture-ran = True;
    }
  }
}

sub find-suite() {
  registry().suites.first({ .file.basename eq 'describe-spec.raku' });
}

sub find-fixture() {
  find-suite().groups.first(*.description eq 'describe-spec fixture');
}

describe 'describe / context / it registration', {
  it 'registers a Suite for the spec file', {
    my $suite = find-suite();
    expect($suite ~~ Suite).to.be(True);
  }

  it 'stores the describe as a top-level group with its description', {
    my $fixture = find-fixture();
    expect($fixture ~~ ExampleGroup).to.be(True);
    expect($fixture.description).to.be('describe-spec fixture');
  }

  it 'registers context as a nested group with the right parent', {
    my $fixture = find-fixture();
    my $inner   = $fixture.groups.first(*.description eq 'describe-spec fixture inner');
    expect($inner ~~ ExampleGroup).to.be(True);
    expect($inner.description).to.be('describe-spec fixture inner');
    expect($inner.parent === $fixture).to.be(True);
  }

  it 'registers examples under the nested group', {
    my $inner = find-fixture().groups[0];
    expect($inner.examples.elems).to.be(1);
    expect($inner.examples[0].description).to.be('fixture example');
  }

  it 'stores the example block as a Callable for deferred execution', {
    my $example = find-fixture().groups[0].examples[0];
    expect($example.block ~~ Callable).to.be(True);
  }
}
