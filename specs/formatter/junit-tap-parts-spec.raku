use BDD::Behave;
use BDD::Behave::Failures;
use BDD::Behave::Formatter::JUnit;
use BDD::Behave::Formatter::TAP;
use BDD::Behave::Runner;
use BDD::Behave::SpecTree;
use Test::Output;

constant Suite        = BDD::Behave::SpecTree::Suite;
constant ExampleGroup = BDD::Behave::SpecTree::ExampleGroup;
constant Example      = BDD::Behave::SpecTree::Example;
constant RunResult    = BDD::Behave::Runner::RunResult;

# Both formatters write one document at the end of the run, so each example
# drives a small run and reads the document back.
sub document-of($formatter, &drive --> Str) {
  my $suite = Suite.new(:description('spec.raku'), :file('/abs/spec.raku'.IO), :line(1));

  stdout-from({
    $formatter.suite-loading(:file('/abs/spec.raku'));
    $formatter.suite-start($suite);
    drive($formatter, $suite);
    $formatter.suite-end($suite);
    $formatter.run-summary(RunResult.new, :order('defined'));
  });
}

sub example-in($suite, Str $description = 'an example' --> Example) {
  my $ex = Example.new(:$description, :file('/abs/spec.raku'.IO), :line(7), :block(sub { }));
  $suite.add-child($ex);
  $ex.duration = 0.25;
  $ex;
}

describe 'the junit document', {
  let(:formatter, { BDD::Behave::Formatter::JUnit.new });

  it 'records an example its around hook never ran as skipped', {
    expect(document-of(formatter(), -> $f, $suite {
      $f.example-around-skipped(example-in($suite));
    })).to.include('around-each did not invoke continuation');
  }

  it 'counts that example in the skipped total', {
    expect(document-of(formatter(), -> $f, $suite {
      $f.example-around-skipped(example-in($suite));
    })).to.include('skipped="1"');
  }

  it 'records the description the runner derived for an example', {
    expect(document-of(formatter(), -> $f, $suite {
      my $ex = example-in($suite);
      $f.example-start($ex);
      $f.example-auto-description($ex, :description('derived from the matcher'));
      $f.example-pass($ex);
    })).to.include('derived from the matcher');
  }

  it 'writes nothing of its own for a group its around hook never ran', {
    expect(document-of(formatter(), -> $f, $suite {
      my $group = ExampleGroup.new(
        :description('a group'), :file('/abs/spec.raku'.IO), :line(5),
      );
      $suite.add-child($group);
      $f.group-around-skipped($group);
    })).to.not.include('a group');
  }

  it 'writes nothing for a slow example', {
    expect(document-of(formatter(), -> $f, $suite {
      $f.example-slow(example-in($suite), :threshold(0.1));
    })).to.not.include('threshold');
  }

  it 'writes no profile section', {
    expect(stdout-from({ formatter().profile-summary([], :limit(5)) })).to.eq('');
  }

  it 'writes no profile section for a run spanning several files', {
    expect(stdout-from({ formatter().multi-file-profile(Nil, [], :limit(5)) })).to.eq('');
  }

  it 'names the aggregation a failure came from', {
    Failures.list = ();

    my $document = document-of(formatter(), -> $f, $suite {
      my $ex = example-in($suite);
      $f.example-start($ex);
      aggregate-failures 'the totals', { expect(1).to.be(2) };
      $f.example-fail($ex, :failure-info(%()));
    });

    Failures.list = ();

    expect($document).to.include('aggregate: the totals');
  }
}

describe 'the tap document', {
  let(:formatter, { BDD::Behave::Formatter::TAP.new });

  it 'records the description the runner derived for an example', {
    expect(document-of(formatter(), -> $f, $suite {
      my $ex = example-in($suite);
      $f.example-start($ex);
      $f.example-auto-description($ex, :description('derived from the matcher'));
      $f.example-pass($ex);
    })).to.include('derived from the matcher');
  }

  it 'writes nothing of its own for a group its around hook never ran', {
    expect(document-of(formatter(), -> $f, $suite {
      my $group = ExampleGroup.new(
        :description('a group'), :file('/abs/spec.raku'.IO), :line(5),
      );
      $suite.add-child($group);
      $f.group-around-skipped($group);
    })).to.not.include('a group');
  }

  it 'writes nothing for a slow example', {
    expect(document-of(formatter(), -> $f, $suite {
      $f.example-slow(example-in($suite), :threshold(0.1));
    })).to.not.include('threshold');
  }

  it 'writes no profile section', {
    expect(stdout-from({ formatter().profile-summary([], :limit(5)) })).to.eq('');
  }

  it 'writes no profile section for a run spanning several files', {
    expect(stdout-from({ formatter().multi-file-profile(Nil, [], :limit(5)) })).to.eq('');
  }
}
