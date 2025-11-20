
use BDD::Behave;

class Foo {
  has $.bar;
  has $.baz;

  submethod BUILD(:$!bar) {
    $!baz = 42;
  }
}

let(:foo, { Foo.new(:bar(17)) });

describe 'Foo', {
  it '.bar', {
    my $foo = $*LET-RUNTIME.value('foo');
    expect($foo.bar).to.be(17);
  }

  it '.baz', {
    my $foo = $*LET-RUNTIME.value('foo');
    expect($foo.baz).to.be(42);
  }
}
