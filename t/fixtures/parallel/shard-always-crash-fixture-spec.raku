use BDD::Behave;

describe 'shard always-crash fixture', {
  it 'crashes every time', {
    exit 137;
  }
}
