use BDD::Behave;
use BDD::Behave::Bisect;

# Driving the bisector directly, rather than through bin/behave, reads back the
# record it keeps of its own work.
my $fixture = $?FILE.IO.parent.parent.parent.add('t/fixtures/bisect-fixture-spec.raku');

describe 'a bisector run over an order-dependent failure', {
  let(:bisector, {
    BDD::Behave::Bisect::Bisector.new(
      :spec-files([$fixture.absolute]),
      :quiet,
    );
  });

  it 'reports that the initial pass found failures', {
    expect(bisector.run.had-failures).to.be-truthy;
  }

  it 'names the failing example it bisected', {
    expect(bisector.run.initial-failing[0].ends-with(':29')).to.be-truthy;
  }

  it 'keeps the minimal prior set it settled on', {
    my $result = bisector.run;
    expect($result.minimal-deps{$result.initial-failing[0]}[0].ends-with(':20')).to.be-truthy;
  }

  it 'counts the subprocess runs it took', {
    my $bis = bisector;
    $bis.run;
    expect($bis.iterations > 1).to.be-truthy;
  }
}
