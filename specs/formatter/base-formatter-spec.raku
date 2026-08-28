use BDD::Behave;
use BDD::Behave::Formatter;
use BDD::Behave::Formatter::Tree;
use BDD::Behave::Runner;
use BDD::Behave::SpecTree;
use Test::Output;

constant Suite     = BDD::Behave::SpecTree::Suite;
constant Example   = BDD::Behave::SpecTree::Example;
constant RunResult = BDD::Behave::Runner::RunResult;

# A formatter written outside behave gets every method from the role and
# overrides only what it cares about, so the defaults are exercised here.
my class BareFormatter does BDD::Behave::Formatter { }

describe 'a formatter that overrides nothing', {
  let(:formatter, { BareFormatter.new });
  let(:suite, { Suite.new(:description('spec.raku'), :file('/abs/spec.raku'.IO), :line(1)) });
  let(:example, {
    Example.new(:description('an example'), :file('/abs/spec.raku'.IO), :line(7), :block(sub { }));
  });

  it 'names itself', {
    expect(formatter().name).to.eq('formatter');
  }

  it 'takes a total without writing anything', {
    expect(stdout-from({ formatter().set-total(42) })).to.eq('');
  }

  it 'takes the start of a suite quietly', {
    expect(stdout-from({ formatter().suite-start(suite()) })).to.eq('');
  }

  it 'takes a passing example quietly', {
    expect(stdout-from({ formatter().example-pass(example()) })).to.eq('');
  }

  it 'takes a failing example quietly', {
    expect(stdout-from({ formatter().example-fail(example(), :failure-info(%())) })).to.eq('');
  }

  it 'takes the end of the run quietly', {
    expect(stdout-from({ formatter().run-summary(RunResult.new) })).to.eq('');
  }
}

describe 'the tree formatter announcing its work', {
  let(:formatter, { BDD::Behave::Formatter::Tree.new });
  let(:example, {
    Example.new(:description('an example'), :file('/abs/spec.raku'.IO), :line(7), :block(sub { }));
  });

  it 'names the file it is loading', {
    expect(stdout-from({ formatter().suite-loading(:file('/abs/spec.raku')) }))
      .to.include('Loading: /abs/spec.raku');
  }

  it 'writes the description the runner derived for an example', {
    expect(stdout-from({
      formatter().example-auto-description(example(), :description('derived from the matcher'));
    })).to.include('derived from the matcher');
  }
}
