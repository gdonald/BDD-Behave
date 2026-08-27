use BDD::Behave;
use BDD::Behave::Formatter::JsonEvents;
use BDD::Behave::Parallel::EventStream;
use BDD::Behave::Runner;
use BDD::Behave::SpecTree;
use Test::Output;

constant Suite        = BDD::Behave::SpecTree::Suite;
constant ExampleGroup = BDD::Behave::SpecTree::ExampleGroup;
constant Example      = BDD::Behave::SpecTree::Example;
constant RetryRecord  = BDD::Behave::Runner::RetryRecord;
constant RunResult    = BDD::Behave::Runner::RunResult;

describe 'the events the json-events formatter emits', {
  let(:formatter, { BDD::Behave::Formatter::JsonEvents.new });

  let(:suite, {
    Suite.new(:description('spec.raku'), :file('/abs/spec.raku'.IO), :line(1));
  });

  let(:group, {
    my $g = ExampleGroup.new(:description('a group'), :file('/abs/spec.raku'.IO), :line(5));
    suite().add-child($g);
    $g;
  });

  let(:example, {
    my $ex = Example.new(
      :description('an example'),
      :file('/abs/spec.raku'.IO),
      :line(7),
      :block(sub { }),
    );
    group().add-child($ex);
    $ex.duration = 0.5;
    $ex;
  });

  # An array literal and a slurpy both flatten a hash into pairs, so the one
  # record each of these summaries takes is pushed onto an array instead.
  sub records-of($record --> Array) {
    my @out;
    @out.push($record);
    @out;
  }

  sub event-of(&emit-it --> Hash) {
    parse-json-event(stdout-from(&emit-it).lines[0]);
  }

  it 'names the formatter', {
    expect(formatter().name).to.eq('json-events');
  }

  context 'loading a spec file', {
    let(:event, { event-of({ formatter().suite-loading(:file('/abs/spec.raku')) }) });

    it 'reports the file being loaded', {
      expect(event()<file>).to.eq('/abs/spec.raku');
    }

    it 'types the event as a suite load', {
      expect(event()<type>).to.eq('suite-loading');
    }
  }

  context 'finishing a suite', {
    let(:event, { event-of({ formatter().suite-end(suite()) }) });

    it 'identifies the suite that finished', {
      expect(event()<id>).to.eq('/abs/spec.raku:1');
    }

    it 'types the event as a suite end', {
      expect(event()<type>).to.eq('suite-end');
    }
  }

  context 'skipping a group through its around hook', {
    let(:event, { event-of({ formatter().group-around-skipped(group()) }) });

    it 'identifies the group that was skipped', {
      expect(event()<id>).to.eq('/abs/spec.raku:5');
    }

    it 'types the event as an around skip', {
      expect(event()<type>).to.eq('group-around-skipped');
    }
  }

  context 'skipping an example through its around hook', {
    let(:event, { event-of({ formatter().example-around-skipped(example()) }) });

    it 'describes the example that was skipped', {
      expect(event()<description>).to.eq('an example');
    }

    it 'reports where the example was declared', {
      expect(event()<line>).to.be(7);
    }
  }

  context 'naming an example the runner described for itself', {
    let(:event, {
      event-of({
        formatter().example-auto-description(example(), :description('derived from the matcher'));
      });
    });

    it 'reports the description the runner derived', {
      expect(event()<description>).to.eq('derived from the matcher');
    }

    it 'identifies the example it belongs to', {
      expect(event()<id>).to.eq('/abs/spec.raku:7');
    }
  }

  context 'a pending example', {
    let(:event, { event-of({ formatter().example-pending(example()) }) });

    it 'types the event as pending', {
      expect(event()<type>).to.eq('example-pending');
    }

    it 'describes the pending example', {
      expect(event()<description>).to.eq('an example');
    }
  }

  context 'a skipped example', {
    let(:event, { event-of({ formatter().example-skipped(example()) }) });

    it 'types the event as skipped', {
      expect(event()<type>).to.eq('example-skipped');
    }

    it 'describes the skipped example', {
      expect(event()<description>).to.eq('an example');
    }
  }

  context 'an example whose body threw', {
    # A thrown exception is what the runner hands over, and only a thrown one
    # carries a backtrace.
    let(:caught, {
      my $error;
      try {
        die 'boom';
        CATCH { default { $error = $_ } }
      }
      $error;
    });

    let(:event, {
      event-of({
        formatter().example-fail(example(), :failure-info(%( :exception(caught()) )));
      });
    });

    it 'reports the message the exception carried', {
      expect(event()<exception-message>).to.eq('boom');
    }

    it 'reports the backtrace of the exception', {
      expect(event()<exception-backtrace>.chars > 0).to.be-truthy;
    }
  }

  context 'retrying an example', {
    let(:event, {
      event-of({ formatter().example-retry(example(), :attempt(2), :max-attempts(3)) });
    });

    it 'reports which attempt this is', {
      expect(event()<attempt>).to.be(2);
    }

    it 'reports how many attempts are allowed', {
      expect(event()<max-attempts>).to.be(3);
    }
  }

  context 'an example running longer than the slow threshold', {
    let(:event, { event-of({ formatter().example-slow(example(), :threshold(0.1)) }) });

    it 'reports the threshold that was passed', {
      expect(event()<threshold>).to.be(0.1);
    }

    it 'reports how long the example took', {
      expect(event()<duration>).to.be(0.5);
    }
  }

  context 'summarizing the examples that were retried', {
    let(:event, {
      event-of({
        formatter().retry-summary(records-of(
          RetryRecord.new(
            :description('an example'),
            :location('/abs/spec.raku:7'),
            :attempts(2),
            :max-attempts(3),
            :outcome('passed'),
          ),
        ));
      });
    });

    it 'reports one record per retried example', {
      expect(event()<type>).to.eq('retry-record');
    }

    it 'reports how the retried example ended', {
      expect(event()<outcome>).to.eq('passed');
    }

    it 'reports how many attempts it took', {
      expect(event()<attempts>).to.be(2);
    }
  }

  context 'summarizing the slowest examples', {
    let(:records, {
      records-of(%( :example(example()), :description('an example'), :duration(0.5) ));
    });

    it 'reports one record per example in the profile', {
      expect(event-of({ formatter().profile-summary(records(), :limit(1)) })<duration>)
        .to.be(0.5);
    }

    it 'identifies the example the record came from', {
      expect(event-of({ formatter().profile-summary(records(), :limit(1)) })<id>)
        .to.eq('/abs/spec.raku:7');
    }

    it 'emits nothing when no records were asked for', {
      expect(stdout-from({ formatter().profile-summary(records(), :limit(0)) })).to.eq('');
    }
  }

  context 'summarizing a benchmark', {
    let(:event, {
      event-of({
        formatter().benchmark-summary-section(
          records-of(%(
            :example(example()),
            :description('an example'),
            :key('a-key'),
            :label('a label'),
            :position(1),
            :runs(3),
            :iterations(10),
            :timings((0.1, 0.2, 0.3)),
            :min(0.1),
            :max(0.3),
            :mean(0.2),
            :median(0.2),
            :total(0.6),
          )),
          [],
        );
      });
    });

    it 'reports the label the benchmark was given', {
      expect(event()<label>).to.eq('a label');
    }

    it 'reports every timing it collected', {
      expect(event()<timings>.elems).to.be(3);
    }

    it 'reports the mean of those timings', {
      expect(event()<mean>).to.be(0.2);
    }
  }

  context 'a benchmark record with no example behind it', {
    let(:event, {
      event-of({
        formatter().benchmark-summary-section(
          records-of(%( :description('detached'), :key('k'), :timings(()) )),
          [],
        );
      });
    });

    it 'reports no identifier', {
      expect(event()<id>).to.eq('');
    }

    it 'reports no line', {
      expect(event()<line>).to.be(0);
    }
  }

  context 'summarizing the run', {
    let(:event, {
      my $result = RunResult.new;
      $result.total = 4;
      $result.passed = 3;
      $result.failed = 1;

      event-of({ formatter().run-summary($result, :order('random'), :seed(99)) });
    });

    it 'reports how many examples ran', {
      expect(event()<total>).to.be(4);
    }

    it 'reports how many failed', {
      expect(event()<failed>).to.be(1);
    }

    it 'reports the seed the run used', {
      expect(event()<seed>).to.be(99);
    }
  }

  context 'reporting spec files that failed to load', {
    let(:event, {
      event-of({
        formatter().load-errors(
          records-of(%( :file('/abs/broken.raku'), :message('boom') )),
        );
      });
    });

    it 'names the file that failed to load', {
      expect(event()<file>).to.eq('/abs/broken.raku');
    }

    it 'reports why it failed', {
      expect(event()<message>).to.eq('boom');
    }
  }
}
