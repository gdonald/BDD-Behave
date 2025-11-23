use BDD::Behave;

describe 'classes in specs', {
  class Widget {
    has $.bar;
    has $.baz;

    submethod BUILD(:$!bar) {
      $!baz = 42;
    }
  }

  it 'can define and use classes with regular variables', {
    my $widget = Widget.new(:bar(17));
    expect($widget.bar).to.be(17);
    expect($widget.baz).to.be(42);
  }

  context 'with binding syntax', {
    it 'provides clean method access', {
      my $w := let(:widget, { Widget.new(:bar(99)) });

      expect($w.bar).to.be(99);
      expect($w.baz).to.be(42);
    }

    it 'each example gets fresh instance', {
      my $w := let(:widget, { Widget.new(:bar(99)) });

      expect($w.bar).to.be(99);
    }
  }

  context 'with traditional let and context parameter', {
    let(:widget, { Widget.new(:bar(88)) });

    it 'accesses via context parameter', -> $_ {
      expect(.widget.bar).to.be(88);
      expect(.widget.baz).to.be(42);
    }

    it 'can check type', {
      expect(:widget).to.be(Widget);
    }
  }

  context 'with different initial values', {
    let(:widget, { Widget.new(:bar(55)) });

    it 'uses the value from this context', {
      my $w := let(:widget, { Widget.new(:bar(55)) });
      expect($w.bar).to.be(55);
    }
  }

  context 'with multiple let bindings', {
    it 'each binding is independent', {
      my $w1 := let(:w1, { Widget.new(:bar(10)) });
      my $w2 := let(:w2, { Widget.new(:bar(20)) });

      expect($w1.bar).to.be(10);
      expect($w2.bar).to.be(20);
    }

    it 'bindings are memoized within example', {
      my $first := let(:first, { Widget.new(:bar(1)) });
      my $second := let(:second, { Widget.new(:bar(2)) });

      # Access multiple times - should be same instances
      expect($first.bar).to.be(1);
      expect($second.bar).to.be(2);
      expect($first.baz).to.be(42);
      expect($second.baz).to.be(42);
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
