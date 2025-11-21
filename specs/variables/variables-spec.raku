use BDD::Behave;

my $top-level-var = 'top-level';
our $package-var = 'package-level';
my @top-array = (1, 2, 3);
my %top-hash = (a => 1, b => 2);

describe 'top-level variables', {
  it 'can access top-level my variable', {
    expect($top-level-var).to.be('top-level');
  }

  it 'can access top-level our variable', {
    expect($package-var).to.be('package-level');
  }

  it 'can access top-level array', {
    expect(@top-array[0]).to.be(1);
    expect(@top-array[1]).to.be(2);
    expect(@top-array[2]).to.be(3);
  }

  it 'can access top-level hash', {
    expect(%top-hash<a>).to.be(1);
    expect(%top-hash<b>).to.be(2);
  }

  it 'can modify top-level variable', {
    my $original = $top-level-var;
    $top-level-var = 'modified';
    expect($top-level-var).to.be('modified');
    $top-level-var = $original;
  }
}

describe 'variables inside describe blocks', {
  my $describe-var = 'describe-level';
  my $counter = 0;

  it 'can access describe-level variable', {
    expect($describe-var).to.be('describe-level');
  }

  it 'describe-level variables are shared across examples', {
    $counter++;
    expect($counter > 0).to.be(True);
  }

  context 'nested context with own variables', {
    my $context-var = 'context-level';

    it 'can access context-level variable', {
      expect($context-var).to.be('context-level');
    }

    it 'can access describe-level variable from context', {
      expect($describe-var).to.be('describe-level');
    }

    it 'can access top-level variable from context', {
      expect($top-level-var).to.be('top-level');
    }
  }
}

describe 'variables inside it blocks', {
  it 'can declare variables inside it block', {
    my $it-var = 'it-level';
    expect($it-var).to.be('it-level');
  }

  it 'it-level variables are not shared between examples', {
    my $it-var = 'different-value';
    expect($it-var).to.be('different-value');
  }

  it 'can use multiple variable types in one example', {
    my $scalar = 42;
    my @array = (1, 2, 3);
    my %hash = (x => 10, y => 20);

    expect($scalar).to.be(42);
    expect(@array[1]).to.be(2);
    expect(%hash<x>).to.be(10);
  }
}

describe 'variable shadowing', {
  my $value = 'outer';

  it 'uses outer value by default', {
    expect($value).to.be('outer');
  }

  context 'with shadowing variable', {
    my $value = 'inner';

    it 'uses inner value in nested context', {
      expect($value).to.be('inner');
    }

    it 'can access both values with explicit scoping', {
      expect($value).to.be('inner');
    }
  }

  it 'outer value unchanged after nested context', {
    expect($value).to.be('outer');
  }

  context 'shadowing in it block', {
    it 'can shadow describe-level variable in it block', {
      my $value = 'it-level';
      expect($value).to.be('it-level');
    }

    it 'describe-level variable unaffected by shadowing in other it', {
      expect($value).to.be('outer');
    }
  }
}

describe 'interaction between let and regular variables', {
  let(:let-var, { 'from-let' });
  my $regular-var = 'from-regular';

  it 'can access both let and regular variables', {
    expect(:let-var).to.be('from-let');
    expect($regular-var).to.be('from-regular');
  }

  it 'can use regular variable to compute let value', {
    let(:computed, { $regular-var ~ '-computed' });
    expect(:computed).to.be('from-regular-computed');
  }

  it 'let is memoized per example, regular is shared', {
    let(:counter, { $regular-var ~ '-' ~ 1 });
    expect(:counter).to.be('from-regular-1');
    expect(:counter).to.be('from-regular-1');
  }

  context 'nested with both types', {
    let(:nested-let, { 'nested-let' });
    my $nested-var = 'nested-regular';

    it 'can access all four variables', {
      expect(:let-var).to.be('from-let');
      expect(:nested-let).to.be('nested-let');
      expect($regular-var).to.be('from-regular');
      expect($nested-var).to.be('nested-regular');
    }
  }
}

describe 'class definitions', {
  class TestClass {
    has $.name;
    has $.value;

    method compute() {
      return $!value * 2;
    }
  }

  it 'can use class defined in describe block', {
    my $obj = TestClass.new(name => 'test', value => 21);
    expect($obj.name).to.be('test');
    expect($obj.value).to.be(21);
    expect($obj.compute()).to.be(42);
  }

  it 'class is accessible in multiple examples', {
    my $obj = TestClass.new(name => 'another', value => 10);
    expect($obj.name).to.be('another');
    expect($obj.compute()).to.be(20);
  }
}

describe 'role definitions', {
  role TestRole {
    has $.role-value;

    method role-method() {
      return 'role-' ~ $!role-value;
    }
  }

  class ClassWithRole does TestRole {
    has $.class-value;
  }

  it 'can use role defined in describe block', {
    my $obj = ClassWithRole.new(role-value => 'test', class-value => 42);
    expect($obj.role-value).to.be('test');
    expect($obj.class-value).to.be(42);
    expect($obj.role-method()).to.be('role-test');
  }
}

describe 'enum definitions', {
  enum Color <Red Green Blue>;

  it 'can use enum values', {
    expect(Red).to.be(Red);
    expect(Green).to.be(Green);
    expect(Blue).to.be(Blue);
  }

  it 'enum values have correct numeric equivalents', {
    my $color = Red;
    expect($color ~~ Color).to.be(True);
  }

  it 'can use enums in variables', {
    my $favorite = Green;
    expect($favorite).to.be(Green);
  }
}

describe 'complex variable scenarios', {
  my $base = 'base';

  context 'first context', {
    my $context1 = $base ~ '-context1';

    it 'combines variables from different scopes', {
      let(:computed, { $context1 ~ '-let' });
      my $it-var = $context1 ~ '-it';

      expect($base).to.be('base');
      expect($context1).to.be('base-context1');
      expect(:computed).to.be('base-context1-let');
      expect($it-var).to.be('base-context1-it');
    }
  }

  context 'second context', {
    my $context2 = $base ~ '-context2';

    it 'has different context variable', {
      expect($context2).to.be('base-context2');
      expect($base).to.be('base');
    }
  }
}

describe 'variables with different sigils', {
  my $scalar = 42;
  my @array = (1, 2, 3, 4, 5);
  my %hash = (x => 10, y => 20, z => 30);

  it 'scalar variables work', {
    expect($scalar).to.be(42);
  }

  it 'array variables work', {
    expect(@array.elems).to.be(5);
    expect(@array[2]).to.be(3);
  }

  it 'hash variables work', {
    expect(%hash.elems).to.be(3);
    expect(%hash<y>).to.be(20);
  }

  it 'can iterate over arrays', {
    my $sum = 0;
    for @array -> $item {
      $sum += $item;
    }
    expect($sum).to.be(15);
  }

  it 'can iterate over hashes', {
    my $sum = 0;
    for %hash.values -> $value {
      $sum += $value;
    }
    expect($sum).to.be(60);
  }
}
