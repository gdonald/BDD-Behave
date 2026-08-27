use BDD::Behave;
use BDD::Behave::Formatter::HTML;
use BDD::Behave::Runner;
use BDD::Behave::SpecTree;
use Test::Output;

constant Suite        = BDD::Behave::SpecTree::Suite;
constant ExampleGroup = BDD::Behave::SpecTree::ExampleGroup;
constant Example      = BDD::Behave::SpecTree::Example;
constant RunResult    = BDD::Behave::Runner::RunResult;

# The formatter collects fragments and writes one page at the end of the run,
# so each example below drives a small run and reads the page back.
sub page-of(&drive, Bool :$multi-file = False --> Str) {
  my $formatter = BDD::Behave::Formatter::HTML.new;
  my $suite = Suite.new(:description('spec.raku'), :file('/abs/spec.raku'.IO), :line(1));

  stdout-from({
    $formatter.suite-loading(:file('/abs/spec.raku'));
    $formatter.suite-start($suite, :$multi-file);
    drive($formatter, $suite);
    $formatter.suite-end($suite);

    if $multi-file {
      $formatter.run-summary(RunResult.new, :order('defined'));
      $formatter.multi-file-overall(RunResult.new, :order('defined'));
    } else {
      $formatter.run-summary(RunResult.new, :order('defined'));
    }
  });
}

sub example-in($suite --> Example) {
  my $ex = Example.new(
    :description('an example'),
    :file('/abs/spec.raku'.IO),
    :line(7),
    :block(sub { }),
  );
  $suite.add-child($ex);
  $ex;
}

describe 'the page the html formatter writes', {
  it 'carries the stylesheet the report needs', {
    expect(page-of(-> $formatter, $suite { })).to.include('.example.pass');
  }

  it 'names the file when the run spans several', {
    expect(page-of(-> $formatter, $suite { }, :multi-file)).to.include('spec.raku</h2>');
  }

  it 'writes nothing for one file of a run that spans several', {
    my $formatter = BDD::Behave::Formatter::HTML.new;
    my $suite = Suite.new(:description('spec.raku'), :file('/abs/spec.raku'.IO), :line(1));

    expect(stdout-from({
      $formatter.suite-start($suite, :multi-file);
      $formatter.run-summary(RunResult.new, :order('defined'));
    })).to.eq('');
  }
}

describe 'the fragment the html formatter writes for a skipped group', {
  let(:page, {
    page-of(-> $formatter, $suite {
      my $group = ExampleGroup.new(
        :description('a group'),
        :file('/abs/spec.raku'.IO),
        :line(5),
      );
      $suite.add-child($group);

      $formatter.group-start($group);
      $formatter.group-around-skipped($group);
      $formatter.group-end($group);
    });
  });

  it 'marks it as skipped', {
    expect(page()).to.include('class="example skipped"');
  }

  it 'says why it was skipped', {
    expect(page()).to.include('around-all did not invoke continuation');
  }
}

describe 'the fragment the html formatter writes for a skipped example', {
  it 'says why the example was skipped', {
    expect(page-of(-> $formatter, $suite {
      $formatter.example-around-skipped(example-in($suite));
    })).to.include('around-each did not invoke continuation');
  }

  it 'marks a plain skip without a reason', {
    expect(page-of(-> $formatter, $suite {
      $formatter.example-skipped(example-in($suite));
    })).to.include('skipped');
  }
}

describe 'the sections the html formatter leaves out', {
  let(:formatter, { BDD::Behave::Formatter::HTML.new });

  it 'writes nothing for a slow example', {
    my $suite = Suite.new(:description('spec.raku'), :file('/abs/spec.raku'.IO), :line(1));

    expect(stdout-from({
      formatter().example-slow(example-in($suite), :threshold(0.1));
    })).to.eq('');
  }

  it 'writes no profile section', {
    expect(stdout-from({ formatter().profile-summary([], :limit(5)) })).to.eq('');
  }

  it 'writes no profile section for a run spanning several files', {
    expect(stdout-from({ formatter().multi-file-profile(Nil, [], :limit(5)) })).to.eq('');
  }

  it 'writes no benchmark section', {
    expect(stdout-from({ formatter().benchmark-summary-section([], []) })).to.eq('');
  }

  it 'writes no benchmark section for a run spanning several files', {
    expect(stdout-from({ formatter().multi-file-benchmark(Nil, [], []) })).to.eq('');
  }
}
