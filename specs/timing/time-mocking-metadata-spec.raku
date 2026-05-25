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
  $result;
}

sub build-suite-with-example(Example $example) {
  my $suite = Suite.create(
    :description('metadata-freeze'),
    :file('synthetic'.IO),
    :line(1),
  );
  my $group = ExampleGroup.new(
    :description('group'),
    :file('synthetic'.IO),
    :line(2),
  );
  $suite.add-group($group);
  $group.add-example($example);
  $suite;
}

describe ':freeze-time metadata = True', {
  it 'freezes time across two `now` reads inside the example body', {
    my @captured;
    my $example = Example.new(
      :description('freezes inside body'),
      :file('synthetic'.IO), :line(10),
      :block({
        my $a = now;
        sleep 0.01;
        my $b = now;
        @captured = $a, $b;
      }),
    );
    $example.set-metadata(:freeze-time(True));

    silent-run(build-suite-with-example($example));

    expect(@captured[0]).to.eq(@captured[1]);
  }
}

describe ':freeze-time metadata with a DateTime value', {
  it 'freezes time at the given DateTime', {
    my $when = DateTime.new('2024-06-15T12:00:00Z');
    my $captured;
    my $example = Example.new(
      :description('frozen at explicit moment'),
      :file('synthetic'.IO), :line(20),
      :block({ $captured = DateTime.now(:timezone(0)); }),
    );
    $example.set-metadata(:freeze-time($when));

    silent-run(build-suite-with-example($example));

    expect($captured.year).to.eq(2024);
    expect($captured.month).to.eq(6);
    expect($captured.day).to.eq(15);
  }
}

describe ':freeze-time metadata with no value (False)', {
  it 'does not freeze when explicit False is passed', {
    my @captured;
    my $example = Example.new(
      :description('not frozen'),
      :file('synthetic'.IO), :line(30),
      :block({
        my $a = now;
        sleep 0.01;
        my $b = now;
        @captured = $a, $b;
      }),
    );
    $example.set-metadata(:freeze-time(False));

    silent-run(build-suite-with-example($example));

    expect(@captured[1]).to.be-greater-than(@captured[0]);
  }
}

describe ':freeze-time leakage between examples', {
  it 'does not leak frozen time into the next example', {
    my $frozen-captured;
    my $unfrozen-captured;

    my $frozen-example = Example.new(
      :description('frozen example'),
      :file('synthetic'.IO), :line(40),
      :block({ $frozen-captured = DateTime.now(:timezone(0)); }),
    );
    $frozen-example.set-metadata(:freeze-time(DateTime.new('2020-05-15T12:00:00Z')));

    my $unfrozen-example = Example.new(
      :description('unfrozen example'),
      :file('synthetic'.IO), :line(41),
      :block({ $unfrozen-captured = DateTime.now; }),
    );

    my $suite = Suite.create(
      :description('leakage-test'),
      :file('synthetic'.IO),
      :line(1),
    );
    my $group = ExampleGroup.new(
      :description('group'),
      :file('synthetic'.IO),
      :line(2),
    );
    $suite.add-group($group);
    $group.add-example($frozen-example);
    $group.add-example($unfrozen-example);

    silent-run($suite);

    expect($frozen-captured.year).to.eq(2020);
    expect($unfrozen-captured.year).to.be-greater-than-or-equal-to(2024);
  }
}

describe ':freeze-time records real wall-clock duration', {
  it 'records non-zero duration even when example body sees frozen time', {
    my $example = Example.new(
      :description('sleeps but sees frozen time'),
      :file('synthetic'.IO), :line(50),
      :block({ sleep 0.05; }),
    );
    $example.set-metadata(:freeze-time(True));

    silent-run(build-suite-with-example($example));

    expect($example.duration ~~ Real).to.be-truthy;
    expect($example.duration).to.be-greater-than-or-equal-to(0.04);
  }
}
