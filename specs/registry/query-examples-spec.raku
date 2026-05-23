use BDD::Behave;
use BDD::Behave::SpecRegistry;
use BDD::Behave::SpecTree;

constant SpecRegistry = BDD::Behave::SpecRegistry::SpecRegistry;
constant ExampleGroup = BDD::Behave::SpecTree::ExampleGroup;
constant Example = BDD::Behave::SpecTree::Example;
constant ExampleQueryResult = BDD::Behave::SpecRegistry::ExampleQueryResult;

sub build-fixture-registry() {
  my $reg = SpecRegistry.new;
  my $file = $*PROGRAM.absolute.IO;
  my $entry = $reg.entry-for($file);

  my $math = ExampleGroup.new(:description('math'), :file($file), :line(20));
  $math.set-metadata(:tags(<arith>));
  $entry.suite.add-group($math);

  my $adds = Example.new(
    :description('adds two numbers'),
    :file($file), :line(22), :block(-> { }),
  );
  $adds.set-metadata(:tags(<fast>));
  $math.add-example($adds);

  my $slow = Example.new(
    :description('multiplies large numbers'),
    :file($file), :line(25), :block(-> { }),
  );
  $slow.set-metadata(:tags(<slow>));
  $slow.set-metadata(:type<integration>);
  $math.add-example($slow);

  my $pending-ex = Example.new(
    :description('factors primes'),
    :file($file), :line(30), :block(-> { }),
  );
  $math.add-example($pending-ex);
  $pending-ex.mark-pending(:reason('TODO'));

  $reg;
}

describe 'SpecRegistry query API', {
  it 'enumerates every example via all-examples', {
    my $reg = build-fixture-registry();
    expect($reg.all-examples.elems).to.eq(3);
  }

  it 'returns ExampleQueryResult records', {
    my $reg = build-fixture-registry();
    my $first = $reg.all-examples[0];
    expect($first ~~ ExampleQueryResult).to.be-truthy;
  }

  it 'builds the joined full-description from ancestor groups', {
    my $reg = build-fixture-registry();
    my $adds = $reg.all-examples.first(*.description eq 'adds two numbers');
    expect($adds.full-description).to.eq('math adds two numbers');
  }

  it 'inherits group tags through effective-tags', {
    my $reg = build-fixture-registry();
    my $adds = $reg.all-examples.first(*.description eq 'adds two numbers');
    expect($adds.tags).to.include('arith');
    expect($adds.tags).to.include('fast');
  }

  it 'filters by include-tags (OR across listed tags)', {
    my $reg = build-fixture-registry();
    expect($reg.query-examples(include-tags => ['slow']).elems).to.eq(1);
  }

  it 'filters by exclude-tags', {
    my $reg = build-fixture-registry();
    my @hit = $reg.query-examples(exclude-tags => ['slow']);
    expect(@hit.elems).to.eq(2);
    expect(@hit.map(*.description).first(* eq 'multiplies large numbers')).to.be(Any);
  }

  it 'filters by description-pattern substring', {
    my $reg = build-fixture-registry();
    my @hit = $reg.query-examples(description-pattern => 'large');
    expect(@hit.elems).to.eq(1);
  }

  it 'filters by description-pattern regex when wrapped in slashes', {
    my $reg = build-fixture-registry();
    my @hit = $reg.query-examples(description-pattern => '/^math \s/');
    expect(@hit.elems).to.eq(3);
  }

  it 'filters by line number', {
    my $reg = build-fixture-registry();
    my @hit = $reg.query-examples(line => 22);
    expect(@hit.elems).to.eq(1);
    expect(@hit[0].description).to.eq('adds two numbers');
  }

  it 'filters by metadata equality', {
    my $reg = build-fixture-registry();
    my @hit = $reg.query-examples(metadata => { type => 'integration' });
    expect(@hit.elems).to.eq(1);
  }

  it 'filters by pending status', {
    my $reg = build-fixture-registry();
    my @hit = $reg.query-examples(pending => True);
    expect(@hit.elems).to.eq(1);
    expect(@hit[0].description).to.eq('factors primes');
  }

  it 'returns example count via count-examples', {
    my $reg = build-fixture-registry();
    expect($reg.count-examples).to.eq(3);
    expect($reg.count-examples(include-tags => ['fast'])).to.eq(1);
  }

  it 'returns full record as a Hash via to-hash for editor integration', {
    my $reg = build-fixture-registry();
    my $first = $reg.all-examples[0];
    my %h = $first.to-hash;
    expect(%h<description> ~~ Str).to.be-truthy;
    expect(%h<line> ~~ Int).to.be-truthy;
    expect(%h<file> ~~ Str).to.be-truthy;
    expect(%h<tags> ~~ Positional).to.be-truthy;
  }
}
