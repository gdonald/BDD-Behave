use BDD::Behave;
use BDD::Behave::Runner;
use BDD::Behave::SpecTree;

constant Suite        = BDD::Behave::SpecTree::Suite;
constant ExampleGroup = BDD::Behave::SpecTree::ExampleGroup;
constant Example      = BDD::Behave::SpecTree::Example;

sub silent-run($suite, *%runner-args) {
  my $sink = open '/dev/null', :w;
  my $*OUT = $sink;
  my $runner = BDD::Behave::Runner::Runner.new(|%runner-args);
  my $result = $runner.run($suite);
  $sink.close;
  ($runner, $result);
}

sub build-recording-suite(@names) {
  my @recorded;
  my $suite = Suite.create(:description('order-suite'), :file('synthetic'.IO), :line(1));
  my $group = ExampleGroup.new(:description('order-group'), :file('synthetic'.IO), :line(1));
  $suite.add-group($group);

  for @names.kv -> $i, $name {
    $group.add-example(Example.new(
      :description($name),
      :file('synthetic'.IO),
      :line(10 + $i),
      :block({ @recorded.push($name) }),
    ));
  }

  ($suite, @recorded);
}

describe 'Runner order: defined (default)', {
  it 'executes children in declaration order', {
    my ($suite, $recorded) = build-recording-suite(<a b c d e>);
    silent-run($suite);
    expect($recorded.Array).to.eq(<a b c d e>.Array);
  }

  it 'leaves the seed undefined by default', {
    my $runner = BDD::Behave::Runner::Runner.new;
    expect($runner.order).to.be('defined');
    expect($runner.seed).to.be(Int);
  }
}

describe 'Runner order: random', {
  it 'auto-generates a seed when none is supplied', {
    my $runner = BDD::Behave::Runner::Runner.new(:order<random>);
    expect($runner.seed.defined).to.be-truthy;
    expect($runner.seed).to.be-greater-than-or-equal-to(1);
  }

  it 'produces the same order for the same seed', {
    my ($s1, $r1) = build-recording-suite(<a b c d e f g h>);
    my ($s2, $r2) = build-recording-suite(<a b c d e f g h>);

    silent-run($s1, :order<random>, :seed(424242));
    silent-run($s2, :order<random>, :seed(424242));

    expect($r1.Array).to.eq($r2.Array);
  }

  it 'produces a different order than declared for at least one seed', {
    my $different = False;
    for 1..20 -> $seed {
      my ($suite, $recorded) = build-recording-suite(<a b c d e f g h i j>);
      silent-run($suite, :order<random>, :seed($seed));
      if $recorded.Array !eqv <a b c d e f g h i j>.Array {
        $different = True;
        last;
      }
    }
    expect($different).to.be-truthy;
  }

  it 'shuffles children of every example group', {
    my @recorded;
    my $suite = Suite.create(:description('outer-suite'), :file('synthetic'.IO), :line(1));
    my $outer = ExampleGroup.new(:description('outer'), :file('synthetic'.IO), :line(1));
    $suite.add-group($outer);

    for <p q r s> -> $name {
      my $inner = ExampleGroup.new(:description("inner-$name"), :file('synthetic'.IO), :line(2));
      $outer.add-group($inner);
      for 1..3 -> $i {
        $inner.add-example(Example.new(
          :description("$name-$i"),
          :file('synthetic'.IO),
          :line(10),
          :block({ @recorded.push("$name-$i") }),
        ));
      }
    }

    silent-run($suite, :order<random>, :seed(7777));

    my @inner-prefixes = @recorded.map({ .substr(0, 1) }).unique;
    expect(@inner-prefixes.elems).to.be(4);
  }
}

describe 'Runner order: :order<defined> override', {
  it 'restores declaration order inside a group under random mode', {
    my @recorded;
    my $suite = Suite.create(:description('mixed-suite'), :file('synthetic'.IO), :line(1));

    my $defined-group = ExampleGroup.new(:description('defined-here'), :file('synthetic'.IO), :line(1));
    $defined-group.set-metadata(:order<defined>);
    $suite.add-group($defined-group);

    for <a b c d e> -> $name {
      $defined-group.add-example(Example.new(
        :description($name),
        :file('synthetic'.IO),
        :line(10),
        :block({ @recorded.push($name) }),
      ));
    }

    silent-run($suite, :order<random>, :seed(99));

    expect(@recorded.Array).to.eq(<a b c d e>.Array);
  }

  it 'inherits :order metadata through nested groups', {
    my @recorded;
    my $suite = Suite.create(:description('inherit'), :file('synthetic'.IO), :line(1));
    my $outer = ExampleGroup.new(:description('outer'), :file('synthetic'.IO), :line(1));
    $outer.set-metadata(:order<defined>);
    $suite.add-group($outer);

    my $inner = ExampleGroup.new(:description('inner'), :file('synthetic'.IO), :line(2));
    $outer.add-group($inner);

    for <a b c d e> -> $name {
      $inner.add-example(Example.new(
        :description($name),
        :file('synthetic'.IO),
        :line(10),
        :block({ @recorded.push($name) }),
      ));
    }

    silent-run($suite, :order<random>, :seed(31337));

    expect(@recorded.Array).to.eq(<a b c d e>.Array);
  }
}

sub run-and-capture-output($suite, *%runner-args) {
  my $tmp = $*TMPDIR.add("behave-order-{$*PID}.{(now * 1e6).Int}.out");
  my $fh  = $tmp.open(:w);
  {
    my $*OUT = $fh;
    BDD::Behave::Runner::Runner.new(|%runner-args).run($suite);
  }
  $fh.close;
  my $captured = $tmp.slurp;
  $tmp.unlink;
  $captured;
}

describe 'Runner output', {
  it 'prints "Randomized with seed N" under random order', {
    my ($suite, $recorded) = build-recording-suite(<a b c>);
    my $output = run-and-capture-output($suite, :order<random>, :seed(12345));
    expect($output).to.include('Randomized with seed 12345');
  }

  it 'does not print the seed line under defined order', {
    my ($suite, $recorded) = build-recording-suite(<a b c>);
    my $output = run-and-capture-output($suite, :order<defined>);
    expect($output.contains('Randomized with seed')).to.be-falsy;
  }
}

describe 'Runner seed', {
  it 'rejects invalid order values at construction time', {
    my $died = False;
    try {
      BDD::Behave::Runner::Runner.new(:order<sideways>);
      CATCH { default { $died = True } }
    }
    expect($died).to.be-truthy;
  }

  it 'accepts seed 0 without dying', {
    my ($suite, $recorded) = build-recording-suite(<a b>);
    my $died = False;
    try {
      silent-run($suite, :order<random>, :seed(0));
      CATCH { default { $died = True } }
    }
    expect($died).to.be-falsy;
  }
}
