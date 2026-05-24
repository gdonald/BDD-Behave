use BDD::Behave;
use BDD::Behave::Formatter;
use BDD::Behave::Formatter::Tree;
use BDD::Behave::Runner;
use BDD::Behave::SpecTree;

constant Suite        = BDD::Behave::SpecTree::Suite;
constant ExampleGroup = BDD::Behave::SpecTree::ExampleGroup;
constant Example      = BDD::Behave::SpecTree::Example;

my class RecordingFormatter does BDD::Behave::Formatter {
  has @.events;

  method group-start($g)            { @!events.push: ('group-start',    $g.description) }
  method group-end($g)              { @!events.push: ('group-end',      $g.description) }
  method group-around-skipped($g)   { @!events.push: ('group-around-skipped', $g.description) }
  method example-start($e, Bool :$auto = False)
                                    { @!events.push: ('example-start',  $e.description, $auto) }
  method example-pass($e)           { @!events.push: ('example-pass',   $e.description) }
  method example-fail($e, :$failure-info)
                                    { @!events.push: ('example-fail',   $e.description) }
  method example-pending($e)        { @!events.push: ('example-pending', $e.description) }
  method example-skipped($e)        { @!events.push: ('example-skipped', $e.description) }
  method example-around-skipped($e) { @!events.push: ('example-around-skipped', $e.description) }
  method example-slow($e, Real :$threshold)
                                    { @!events.push: ('example-slow', $e.description) }
  method example-memory-leak($e, Int :$threshold)
                                    { @!events.push: ('example-memory-leak', $e.description) }
  method example-auto-description($e, Str :$description)
                                    { @!events.push: ('example-auto-description', $description) }
  method run-summary($r, Bool :$aborted = False, Int :$fail-fast = 0,
                    Str :$order = 'defined', Int :$seed)
                                    { @!events.push: ('run-summary', $r.total) }
}

sub build-suite(@example-specs) {
  my $suite = Suite.create(:description('synthetic'), :file('synth'.IO), :line(1));
  my $group = ExampleGroup.new(:description('group'), :file('synth'.IO), :line(1));
  $suite.add-group($group);
  for @example-specs.kv -> $i, %spec {
    $group.add-example(Example.new(
      :description(%spec<description>),
      :file('synth'.IO),
      :line(10 + $i),
      :block(%spec<block>),
      :pending(%spec<pending> // False),
    ));
  }
  $suite;
}

describe 'Runner integration with a custom formatter', {
  it 'routes group-start / group-end through the formatter', {
    my $f = RecordingFormatter.new;
    my $suite = build-suite([
      %( description => 'p', block => { Nil } ),
    ]);
    BDD::Behave::Runner::Runner.new(:formatter($f)).run($suite);
    my @names = $f.events.map({ $_[0] });
    expect(@names).to.include('group-start');
    expect(@names).to.include('group-end');
  }

  it 'routes example-pass through the formatter', {
    my $f = RecordingFormatter.new;
    my $suite = build-suite([
      %( description => 'passing example', block => { Nil } ),
    ]);
    BDD::Behave::Runner::Runner.new(:formatter($f)).run($suite);
    expect($f.events.first({ $_[0] eq 'example-pass' }).defined).to.be-truthy;
  }

  it 'routes example-fail through the formatter', {
    my $f = RecordingFormatter.new;
    my $suite = build-suite([
      %( description => 'broken', block => { die 'boom' } ),
    ]);
    BDD::Behave::Runner::Runner.new(:formatter($f)).run($suite);
    expect($f.events.first({ $_[0] eq 'example-fail' }).defined).to.be-truthy;
  }

  it 'routes example-pending through the formatter', {
    my $f = RecordingFormatter.new;
    my $suite = build-suite([
      %( description => 'todo', block => { Nil }, pending => True ),
    ]);
    BDD::Behave::Runner::Runner.new(:formatter($f)).run($suite);
    expect($f.events.first({ $_[0] eq 'example-pending' }).defined).to.be-truthy;
  }

  it 'invokes run-summary after the suite completes', {
    my $f = RecordingFormatter.new;
    my $suite = build-suite([
      %( description => 'p', block => { Nil } ),
    ]);
    BDD::Behave::Runner::Runner.new(:formatter($f)).run($suite);
    expect($f.events.first({ $_[0] eq 'run-summary' }).defined).to.be-truthy;
  }

  it 'defaults to a Tree formatter when none is supplied', {
    my $runner = BDD::Behave::Runner::Runner.new;
    expect($runner.formatter).to.be-a(BDD::Behave::Formatter::Tree);
  }

  it 'accepts a custom formatter via the constructor', {
    my $f      = RecordingFormatter.new;
    my $runner = BDD::Behave::Runner::Runner.new(:formatter($f));
    expect($runner.formatter).to.be($f);
  }
}
