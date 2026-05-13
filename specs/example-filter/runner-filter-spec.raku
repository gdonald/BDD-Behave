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

sub build-suite(@groups) {
  my $suite = Suite.create(
    :description('synthetic'),
    :file('synthetic'.IO),
    :line(1),
  );

  my $line = 10;
  for @groups -> %g {
    my $group = ExampleGroup.new(
      :description(%g<description>),
      :file('synthetic'.IO),
      :line($line++),
    );
    $group.set-metadata(:tags(%g<tags>.list)) if %g<tags>:exists;
    $suite.add-group($group);

    for %g<examples>.list -> %e {
      my $ex = Example.new(
        :description(%e<description>),
        :file('synthetic'.IO),
        :line($line++),
        :block(%e<block> // { True }),
      );
      $ex.set-metadata(:tags(%e<tags>.list)) if %e<tags>:exists;
      $group.add-example($ex);
    }
  }

  $suite;
}

describe 'Runner --example filtering', {
  context 'with no example-patterns', {
    it 'runs every example (existing default)', {
      my @ran;
      my $suite = build-suite([
        %( description => 'group',
           examples => [
             %( description => 'a', block => { @ran.push('a') } ),
             %( description => 'b', block => { @ran.push('b') } ),
           ],
        ),
      ]);

      silent-run($suite);
      expect(@ran.sort.join(',')).to.be('a,b');
    }
  }

  context 'with a single substring pattern', {
    it 'matches against the example description', {
      my @ran;
      my $suite = build-suite([
        %( description => 'fruits',
           examples => [
             %( description => 'apple',  block => { @ran.push('apple')  } ),
             %( description => 'banana', block => { @ran.push('banana') } ),
             %( description => 'cherry', block => { @ran.push('cherry') } ),
           ],
        ),
      ]);

      silent-run($suite, :example-patterns(['banana']));
      expect(@ran.join(',')).to.be('banana');
    }

    it 'matches against the group description and pulls every example in the group', {
      my @ran;
      my $suite = build-suite([
        %( description => 'User signup',
           examples => [
             %( description => 'creates account', block => { @ran.push('signup-create') } ),
             %( description => 'rejects dupes',   block => { @ran.push('signup-reject') } ),
           ],
        ),
        %( description => 'Order checkout',
           examples => [
             %( description => 'totals', block => { @ran.push('order-total') } ),
           ],
        ),
      ]);

      silent-run($suite, :example-patterns(['User signup']));
      expect(@ran.sort.join(',')).to.be('signup-create,signup-reject');
    }
  }

  context 'with multiple patterns', {
    it 'composes them with OR semantics', {
      my @ran;
      my $suite = build-suite([
        %( description => 'group',
           examples => [
             %( description => 'alpha',   block => { @ran.push('alpha') } ),
             %( description => 'bravo',   block => { @ran.push('bravo') } ),
             %( description => 'charlie', block => { @ran.push('charlie') } ),
           ],
        ),
      ]);

      silent-run($suite, :example-patterns(['alpha', 'charlie']));
      expect(@ran.sort.join(',')).to.be('alpha,charlie');
    }
  }

  context 'combined with --tag', {
    it 'requires both filters to match (AND)', {
      my @ran;
      my $suite = build-suite([
        %( description => 'User signup',
           examples => [
             %( description => 'fast happy',  tags => ['fast'], block => { @ran.push('signup-fast') } ),
             %( description => 'slow path',   tags => ['slow'], block => { @ran.push('signup-slow') } ),
           ],
        ),
        %( description => 'Order checkout',
           examples => [
             %( description => 'fast happy', tags => ['fast'], block => { @ran.push('checkout-fast') } ),
           ],
        ),
      ]);

      silent-run(
        $suite,
        :example-patterns(['User signup']),
        :include-tags(['fast']),
      );

      expect(@ran.join(',')).to.be('signup-fast');
    }
  }

  context 'combined with --exclude-tag', {
    it 'still drops excluded examples even when --example matches', {
      my @ran;
      my $suite = build-suite([
        %( description => 'User signup',
           examples => [
             %( description => 'happy', tags => ['fast'],  block => { @ran.push('happy') } ),
             %( description => 'flaky', tags => ['flaky'], block => { @ran.push('flaky') } ),
             %( description => 'plain',                    block => { @ran.push('plain') } ),
           ],
        ),
      ]);

      silent-run(
        $suite,
        :example-patterns(['User signup']),
        :exclude-tags(['flaky']),
      );

      expect(@ran.sort.join(',')).to.be('happy,plain');
    }
  }

  context 'with the /regex/ form', {
    it 'matches by Raku regex when wrapped in slashes', {
      my @ran;
      my $suite = build-suite([
        %( description => 'numbers',
           examples => [
             %( description => 'returns 42',  block => { @ran.push('42') } ),
             %( description => 'returns 100', block => { @ran.push('100') } ),
             %( description => 'returns abc', block => { @ran.push('abc') } ),
           ],
        ),
      ]);

      silent-run($suite, :example-patterns(['/\d+/']));
      expect(@ran.sort.join(',')).to.be('100,42');
    }
  }

  context 'when a pattern matches nothing', {
    it 'reports zero total examples and exits successfully', {
      my $suite = build-suite([
        %( description => 'group',
           examples => [
             %( description => 'a' ),
             %( description => 'b' ),
           ],
        ),
      ]);

      my $result = silent-run($suite, :example-patterns(['no-such-thing']));
      expect($result.total).to.be(0);
      expect($result.success).to.be-truthy;
    }
  }
}
