use BDD::Behave;

class IsolationCollider {
  method which { 'a' }
  method greet { 'hello from a' }
}

class X::Isolation::SharedFamily is Exception {
  has Str $.where = 'a';
  method message { "raised from {$.where}" }
}

describe 'cross-file isolation - file A', {
  it 'sees its own IsolationCollider definition', {
    expect(IsolationCollider.new.which).to.be('a');
  }

  it 'preserves short class name in failure messages', {
    expect(IsolationCollider.^name).to.be('IsolationCollider');
  }

  it 'sees its own compound-name exception', {
    my $err = X::Isolation::SharedFamily.new;
    expect($err.where).to.be('a');
  }

  it 'preserves short compound name on the exception class', {
    expect(X::Isolation::SharedFamily.^name).to.be('X::Isolation::SharedFamily');
  }
}
