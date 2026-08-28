use BDD::Behave;
use BDD::Behave::Failure;

# The exception the runner throws when an expectation fails carries the place
# it failed, and reads it back in its message.
describe 'the expectation failed exception', {
  let(:failed, {
    X::BDD::Behave::ExpectationFailed.new(:file('specs/core/basic-spec.raku'), :line(12));
  });

  it 'names the file and the line in its message', {
    expect(failed.message).to.eq('expectation failed at specs/core/basic-spec.raku:12');
  }

  it 'reads the file back', {
    expect(failed.file).to.eq('specs/core/basic-spec.raku');
  }

  it 'reads the line back', {
    expect(failed.line).to.eq(12);
  }
}
