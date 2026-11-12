use BDD::Behave;
use BDD::Behave::Failures;
use BDD::Behave::Formatter::Documentation;
use BDD::Behave::Formatter::Tree;
use BDD::Behave::Runner;
use BDD::Behave::SpecTree;
use Test::Output;

constant Suite        = BDD::Behave::SpecTree::Suite;
constant ExampleGroup = BDD::Behave::SpecTree::ExampleGroup;
constant Example      = BDD::Behave::SpecTree::Example;

sub strip-ansi(Str $text) { $text.subst(/ \x1b '[' <[0..9;]>+ 'm' /, '', :g) }

sub one-liner-suite(&block) {
  my $suite = Suite.create(:description('synthetic'), :file('synth'.IO), :line(1));
  my $group = ExampleGroup.new(:description('a number'), :file('synth'.IO), :line(1));
  $suite.add-group($group);

  $group.add-example(Example.new(
    :description('example at synth:7'),
    :file('synth'.IO),
    :line(7),
    :&block,
    :metadata(%( auto-description => True )),
  ));

  $suite;
}

sub run-one-liner($formatter, &block) {
  my $runner   = BDD::Behave::Runner::Runner.new(:$formatter);
  my $snapshot = Failures.list.elems;

  my $output = strip-ansi stdout-from({ $runner.run(one-liner-suite(&block)) });
  my @failures = Failures.list[$snapshot ..^ Failures.list.elems];
  Failures.list.splice($snapshot);

  %( :$output, :@failures );
}

describe 'a one-liner example under the documentation formatter', {
  let(:formatter, { BDD::Behave::Formatter::Documentation.new });

  context 'when it passes', {
    let(:run, { run-one-liner(formatter(), { expect(42).to.eq(42) }) });

    it 'prints the description derived from its matcher', {
      expect(run()<output>.lines).to.include('  should eq 42');
    }

    it 'leaves its placeholder description out of the output', {
      expect(run()<output>).to.not.include('example at synth:7');
    }
  }

  context 'when it fails', {
    let(:run, { run-one-liner(formatter(), { expect(42).to.eq(7) }) });

    it 'marks the derived description as failed', {
      expect(run()<output>.lines).to.include('  should eq 7 (FAILED)');
    }

    it 'leaves its placeholder description out of the output', {
      expect(run()<output>).to.not.include('example at synth:7');
    }

    it 'records the failure under the derived description', {
      expect(run()<failures>.map(*.description).List).to.eq(('a number should eq 7',));
    }
  }

  context 'when its block runs no matcher', {
    let(:run, { run-one-liner(formatter(), { 1 + 1 }) });

    it 'prints its placeholder description', {
      expect(run()<output>.lines).to.include('  example at synth:7');
    }
  }
}

describe 'a one-liner example under the tree formatter', {
  let(:formatter, { BDD::Behave::Formatter::Tree.new });

  context 'when it passes', {
    let(:run, { run-one-liner(formatter(), { expect(42).to.eq(42) }) });

    it 'names the example once, with the description derived from its matcher', {
      expect(run()<output>.lines.grep(*.contains("'should eq 42'")).elems).to.eq(1);
    }
  }

  context 'when it fails', {
    let(:run, { run-one-liner(formatter(), { expect(42).to.eq(7) }) });

    it 'names the example once, with the description derived from its matcher', {
      expect(run()<output>.lines.grep(*.contains("'should eq 7'")).elems).to.eq(1);
    }
  }
}
