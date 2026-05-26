use BDD::Behave;
use ImportRepro::X;

describe 'b', {
  it 'sees X::ImportRepro::Boom from its own use', {
    expect(X::ImportRepro::Boom.^name).to.eq('X::ImportRepro::Boom');
  }
}
