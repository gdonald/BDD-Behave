use BDD::Behave;
use DBIish;
use ImportRepro::X;

DBIish.connect('SQLite', :database(':memory:')).dispose;

describe 'a', {
  it 'sees X::ImportRepro::Boom after DBIish.connect at file load', {
    expect(X::ImportRepro::Boom.^name).to.eq('X::ImportRepro::Boom');
  }
}
