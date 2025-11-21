use BDD::Behave;

describe 'classes in specs', {
  class Foo {
    has $.bar;
    has $.baz;

    submethod BUILD(:$!bar) {
      $!baz = 42;
    }
  }

  it 'can define and use classes with regular variables', {
    my $foo = Foo.new(:bar(17));
    expect($foo.bar).to.be(17);
    expect($foo.baz).to.be(42);
  }

  context 'using let with class instances', {
    let(:foo, { Foo.new(:bar(99)) });

    it 'can use let with objects', {
      my $f = $*LET-RUNTIME.value('foo');
      expect($f.bar).to.be(99);
      expect($f.baz).to.be(42);
    }

    it 'each example gets a fresh instance', {
      my $f = $*LET-RUNTIME.value('foo');
      expect($f.bar).to.be(99);
    }
  }

  it 'can use class methods', {
    class Calculator {
      method add($a, $b) { $a + $b }
      method multiply($a, $b) { $a * $b }
    }

    my $calc = Calculator.new;
    expect($calc.add(2, 3)).to.be(5);
    expect($calc.multiply(4, 5)).to.be(20);
  }
}
