use BDD::Behave;
use BDD::Behave::Formatter::JSON;
use BDD::Behave::Parallel::EventStream;
use BDD::Behave::Runner;
use BDD::Behave::SpecTree;
use Test::Output;

constant Suite     = BDD::Behave::SpecTree::Suite;
constant Example   = BDD::Behave::SpecTree::Example;
constant RunResult = BDD::Behave::Runner::RunResult;

# The formatter builds one document for the whole run, so each example below
# drives a small run through it and reads the document back.
sub document-of(&drive --> Hash) {
  my $formatter = BDD::Behave::Formatter::JSON.new;
  my $suite = Suite.new(:description('spec.raku'), :file('/abs/spec.raku'.IO), :line(1));

  my $output = stdout-from({
    $formatter.suite-start($suite);
    drive($formatter, $suite);
    $formatter.run-summary(RunResult.new, :order('defined'));
  });

  parse-json-event($output.lines[0]);
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

describe 'the record the json formatter writes for a failed example', {
  context 'given a failure carrying a rendered message', {
    let(:failure, {
      document-of(-> $formatter, $suite {
        $formatter.example-fail(
          example-in($suite),
          :failure-info(%( :message('a rendered message') )),
        );
      })<examples>[0]<failure>;
    });

    it 'records it as an exception', {
      expect(failure()<type>).to.eq('exception');
    }

    it 'records the message', {
      expect(failure()<message>).to.eq('a rendered message');
    }
  }

  context 'given a failure carrying an exception message', {
    let(:failure, {
      document-of(-> $formatter, $suite {
        $formatter.example-fail(
          example-in($suite),
          :failure-info(%( :exception-message('a thrown message') )),
        );
      })<examples>[0]<failure>;
    });

    it 'records it as an exception', {
      expect(failure()<type>).to.eq('exception');
    }

    it 'records the message', {
      expect(failure()<message>).to.eq('a thrown message');
    }
  }

  context 'given a failure carrying an exception object', {
    let(:failure, {
      my $caught;
      try {
        die 'boom';
        CATCH { default { $caught = $_ } }
      }

      document-of(-> $formatter, $suite {
        $formatter.example-fail(example-in($suite), :failure-info(%( :exception($caught) )));
      })<examples>[0]<failure>;
    });

    it 'records the message the exception carried', {
      expect(failure()<message>).to.eq('boom');
    }
  }
}

describe 'the record the json formatter writes for an example that did not run', {
  context 'given a pending example with a reason', {
    let(:record, {
      document-of(-> $formatter, $suite {
        my $ex = example-in($suite);
        $ex.mark-pending(:reason('not written yet'));
        $formatter.example-pending($ex);
      })<examples>[0];
    });

    it 'records it as pending', {
      expect(record()<status>).to.eq('pending');
    }

    it 'records the reason', {
      expect(record()<pending_reason>).to.eq('not written yet');
    }
  }

  context 'given a skipped example', {
    it 'records it as skipped', {
      expect(document-of(-> $formatter, $suite {
        $formatter.example-skipped(example-in($suite));
      })<examples>[0]<status>).to.eq('skipped');
    }
  }

  context 'given an example whose around hook never ran it', {
    it 'records why it was skipped', {
      expect(document-of(-> $formatter, $suite {
        $formatter.example-around-skipped(example-in($suite));
      })<examples>[0]<skip_reason>).to.include('around-each');
    }
  }
}

describe 'a json run spanning several spec files', {
  let(:formatter, { BDD::Behave::Formatter::JSON.new });
  let(:suite, { Suite.new(:description('spec.raku'), :file('/abs/spec.raku'.IO), :line(1)) });

  it 'writes nothing when one file finishes', {
    expect(stdout-from({
      formatter().suite-start(suite(), :multi-file);
      formatter().run-summary(RunResult.new, :order('defined'));
    })).to.eq('');
  }

  it 'writes the document when the whole run finishes', {
    my $output = stdout-from({
      formatter().suite-start(suite(), :multi-file);
      formatter().run-summary(RunResult.new, :order('defined'));
      formatter().multi-file-overall(RunResult.new, :order('defined'), :seed(7));
    });

    expect(parse-json-event($output.lines[0])<seed>).to.be(7);
  }

  it 'writes no profile section of its own', {
    expect(stdout-from({ formatter().multi-file-profile(Nil, [], :limit(5)) })).to.eq('');
  }
}
