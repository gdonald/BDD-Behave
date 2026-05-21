use BDD::Behave;
use BDD::Behave::Formatter::JsonEvents;
use BDD::Behave::Parallel::EventStream;
use BDD::Behave::SpecTree;
use Test::Output;

constant Suite        = BDD::Behave::SpecTree::Suite;
constant ExampleGroup = BDD::Behave::SpecTree::ExampleGroup;
constant Example      = BDD::Behave::SpecTree::Example;

describe 'BDD::Behave::Formatter::JsonEvents', {
  let(:fmt, { BDD::Behave::Formatter::JsonEvents.new });
  let(:file, { '/abs/spec.raku'.IO });
  let(:suite, {
    my $s = Suite.new(:description('spec.raku'), :file($*LET-RUNTIME.value('file')), :line(1));
    my $g = ExampleGroup.new(:description('outer'), :file($*LET-RUNTIME.value('file')), :line(5));
    $s.add-child($g);
    my $ex = Example.new(
      :description('an example'),
      :file($*LET-RUNTIME.value('file')),
      :line(7),
      :block(sub { }),
    );
    $g.add-child($ex);
    $ex.duration = 0.125;
    $s;
  });

  it 'emits a suite-start event with id and description', {
    my $s = $*LET-RUNTIME.value('suite');
    my $out = stdout-from { $*LET-RUNTIME.value('fmt').suite-start($s) };
    my %ev = parse-json-event($out.lines[0]);
    expect(%ev<type>).to.be('suite-start');
    expect(%ev<description>).to.be('spec.raku');
  }

  it 'emits an example-pass event with duration', {
    my $s = $*LET-RUNTIME.value('suite');
    my $ex = $s.children[0].children[0];
    my $out = stdout-from { $*LET-RUNTIME.value('fmt').example-pass($ex) };
    my %ev = parse-json-event($out.lines[0]);
    expect(%ev<type>).to.be('example-pass');
    expect(%ev<duration>).to.be(0.125);
  }

  it 'survives quotes and newlines in descriptions (JSON round-trip)', {
    my $tricky = Example.new(
      :description("with \"quotes\"\nand a newline"),
      :file($*LET-RUNTIME.value('file')),
      :line(99),
      :block(sub { }),
    );
    $tricky.duration = 0.0;
    my $out = stdout-from { $*LET-RUNTIME.value('fmt').example-start($tricky) };
    my %ev = parse-json-event($out.lines[0]);
    expect(%ev<description>).to.be("with \"quotes\"\nand a newline");
  }
}
