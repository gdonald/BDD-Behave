use BDD::Behave;

class IsolationCollider {
  method which { 'b' }
  method farewell { 'bye from b' }
}

class X::Isolation::SharedFamily is Exception {
  has Str $.where = 'b';
  method message { "raised from {$.where}" }
}

describe 'cross-file isolation - file B', {
  it 'sees its own IsolationCollider definition', {
    expect(IsolationCollider.new.which).to.be('b');
  }

  it 'does not see the other-file definition leak through farewell', {
    expect(IsolationCollider.new.farewell).to.be('bye from b');
  }

  it 'sees its own compound-name exception', {
    my $err = X::Isolation::SharedFamily.new;
    expect($err.where).to.be('b');
  }

  it 'preserves short compound name on the exception class', {
    expect(X::Isolation::SharedFamily.^name).to.be('X::Isolation::SharedFamily');
  }
}
