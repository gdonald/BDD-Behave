use BDD::Behave;
use BDD::Behave::Bisect;
use Test::Output;

constant Bisector = BDD::Behave::Bisect::Bisector;

my $root    = $?FILE.IO.parent.parent.parent;
my $fixture = $root.add('t/fixtures/bisect-fixture-spec.raku');
my $failing = $root.add('t/fixtures/failing-fixture-spec.raku');
my $passing = $root.add('specs/expectations/be-between-spec.raku');
my $pair    = $root.add('t/fixtures/bisect-pair-fixture-spec.raku');

# Each run spawns one behave subprocess per iteration, so the bisector is run
# once per describe and the examples read the result it produced.
sub bisect-of(@files, *%options) {
  Bisector.new(:spec-files(@files.map(*.absolute)), :quiet, |%options).run;
}

describe 'bisecting a run with no failures', {
  let(:result, { bisect-of([$passing]) });

  it 'reports that nothing failed', {
    expect(result().had-failures).to.be-falsy;
  }

  it 'says there was no work to do', {
    expect(result().message).to.eq('no failures');
  }

  it 'names no failing example', {
    expect(result().initial-failing.elems).to.be(0);
  }

  it 'counts the pass it made', {
    expect(result().iterations).to.be(1);
  }
}

describe 'bisecting a failure that reproduces on its own', {
  let(:result, { bisect-of([$failing]) });

  it 'reports that something failed', {
    expect(result().had-failures).to.be-truthy;
  }

  it 'records no prior examples for it', {
    expect(result().minimal-deps.values.map(*.elems).sum).to.be(0);
  }
}

describe 'bisecting an order-dependent failure', {
  let(:result, { bisect-of([$fixture]) });

  let(:dependency, {
    result().minimal-deps{result().initial-failing[0]}.list;
  });

  it 'finds the one example the failure depends on', {
    expect(dependency().elems).to.be(1);
  }

  it 'names the example that pollutes the counter', {
    expect(dependency()[0].ends-with(':20')).to.be-truthy;
  }

  it 'takes more than one pass to get there', {
    expect(result().iterations > 1).to.be-truthy;
  }
}

describe 'a bisector asked to report what it runs', {
  it 'writes each command it spawns', {
    my $output = stderr-from({ bisect-of([$passing], :verbose) });

    expect($output).to.include('--bisect-data');
  }
}

describe 'bisecting a failure that needs two prior examples', {
  let(:result, { bisect-of([$pair]) });

  it 'keeps both examples the failure needs', {
    expect(result().minimal-deps{result().initial-failing[0]}.elems).to.be(2);
  }

  it 'prunes the list one example at a time to get there', {
    expect(result().iterations > 4).to.be-truthy;
  }
}
