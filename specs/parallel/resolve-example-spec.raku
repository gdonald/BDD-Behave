use BDD::Behave;
use BDD::Behave::Parallel;

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
