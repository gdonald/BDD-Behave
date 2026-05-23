use BDD::Behave;
use BDD::Behave::Failure;
use BDD::Behave::Failures;
use BDD::Behave::Formatter;
use BDD::Behave::Formatter::JSON;
use BDD::Behave::SpecTree;

constant Suite        = BDD::Behave::SpecTree::Suite;
constant ExampleGroup = BDD::Behave::SpecTree::ExampleGroup;
constant Example      = BDD::Behave::SpecTree::Example;

sub make-group(Str $description) {
  ExampleGroup.new(:$description, :file('synth'.IO), :line(1));
}

sub make-example(Str $description, Bool :$pending = False, Int :$line = 1) {
  Example.new(
    :$description, :file('synth-spec.raku'.IO), :$line,
    :block({ Nil }), :$pending,
  );
}

sub capture-formatter-output(&block) {
  my $buf = $*TMPDIR.add("json-fmt-{$*PID}-{(now * 1e6).Int}.out");
  my $fh  = open $buf, :w;
  { my $*OUT = $fh; block(); }
  $fh.close;
  my $text = $buf.slurp;
  $buf.unlink;
  $text;
}

sub fake-result(%counts) {
  class :: {
    has Int $.total   is rw = 0;
    has Int $.passed  is rw = 0;
    has Int $.failed  is rw = 0;
    has Int $.pending is rw = 0;
    has Int $.skipped is rw = 0;
  }.new(|%counts);
}

describe 'BDD::Behave::Formatter::JSON', {
  it 'composes the Formatter role', {
    expect(BDD::Behave::Formatter::JSON.new).to.be-a(BDD::Behave::Formatter);
  }

  it 'reports its name as "json"', {
    expect(BDD::Behave::Formatter::JSON.new.name).to.eq('json');
  }

  describe 'document emission', {
    it 'emits exactly one JSON object on run-summary in single-file mode', {
      my $f = BDD::Behave::Formatter::JSON.new;
      my $out = capture-formatter-output({
        $f.run-summary(fake-result(%( total => 0 )), :order('defined'));
      });
      my @lines = $out.lines.grep(*.chars);
      expect(@lines.elems).to.eq(1);
      expect(@lines[0].starts-with('{')).to.be-truthy;
      expect(@lines[0].ends-with('}')).to.be-truthy;
    }

    it 'includes version, summary, summary_line, seed, order, and examples', {
      my $f = BDD::Behave::Formatter::JSON.new;
      my $out = capture-formatter-output({
        $f.run-summary(fake-result(%( total => 0 )), :order('random'), :seed(42));
      });
      expect($out).to.include('"version":1');
      expect($out).to.include('"summary":');
      expect($out).to.include('"summary_line":');
      expect($out).to.include('"order":"random"');
      expect($out).to.include('"seed":42');
      expect($out).to.include('"examples":[]');
    }

    it 'does not emit on per-suite run-summary in multi-file mode', {
      my $f = BDD::Behave::Formatter::JSON.new;
      my $s = Suite.create(:description('s'), :file('/tmp/a-spec.raku'.IO), :line(1));
      my $out = capture-formatter-output({
        $f.suite-start($s, :multi-file);
        $f.run-summary(fake-result(%( total => 0 )));
      });
      expect($out).to.eq('');
    }

    it 'emits at multi-file-overall when in multi-file mode', {
      my $f = BDD::Behave::Formatter::JSON.new;
      my $s = Suite.create(:description('s'), :file('/tmp/a-spec.raku'.IO), :line(1));
      my $out = capture-formatter-output({
        $f.suite-start($s, :multi-file);
        $f.run-summary(fake-result(%( total => 0 )));
        $f.multi-file-overall(fake-result(%( total => 0 )), :order('defined'));
      });
      expect($out.lines.grep(*.starts-with('{')).elems).to.eq(1);
    }

    it 'never emits twice', {
      my $f = BDD::Behave::Formatter::JSON.new;
      my $out = capture-formatter-output({
        $f.run-summary(fake-result(%( total => 1, passed => 1 )));
        $f.run-summary(fake-result(%( total => 1, passed => 1 )));
      });
      expect($out.lines.grep(*.starts-with('{')).elems).to.eq(1);
    }
  }

  describe 'example records', {
    it 'records a passing example with status "passed"', {
      my $f = BDD::Behave::Formatter::JSON.new;
      my $g = make-group('Calculator');
      my $ex = make-example('adds positive numbers', :line(7));
      $ex.duration = 0.001;
      my $out = capture-formatter-output({
        $f.group-start($g);
        $f.example-start($ex);
        $f.example-pass($ex);
        $f.group-end($g);
        $f.run-summary(fake-result(%( total => 1, passed => 1 )));
      });
      expect($out).to.include('"status":"passed"');
      expect($out).to.include('"description":"adds positive numbers"');
      expect($out).to.include('"full_description":"Calculator adds positive numbers"');
      expect($out).to.include('"line":7');
    }

    it 'records a failing example with status "failed" and a failure block', {
      my $f = BDD::Behave::Formatter::JSON.new;
      my $g = make-group('g');
      my $ex = make-example('broken');
      my $exception;
      try { die 'boom'; CATCH { default { $exception = $_ } } }
      my $out = capture-formatter-output({
        $f.group-start($g);
        $f.example-start($ex);
        $f.example-fail($ex, :failure-info(%(
          file => 'spec.raku', line => 9,
          exception => $exception,
        )));
        $f.group-end($g);
        $f.run-summary(fake-result(%( total => 1, failed => 1 )));
      });
      expect($out).to.include('"status":"failed"');
      expect($out).to.include('"failure":');
      expect($out).to.include('"type":"exception"');
      expect($out).to.include('"message":"boom"');
    }

    it 'records pending examples with pending_reason from metadata', {
      my $f = BDD::Behave::Formatter::JSON.new;
      my $g = make-group('g');
      my $ex = make-example('todo', :pending);
      $ex.set-metadata(:pending-reason('not yet implemented'));
      my $out = capture-formatter-output({
        $f.group-start($g);
        $f.example-pending($ex);
        $f.run-summary(fake-result(%( total => 1, pending => 1 )));
      });
      expect($out).to.include('"status":"pending"');
      expect($out).to.include('"pending_reason":"not yet implemented"');
    }

    it 'records skipped examples with status "skipped"', {
      my $f = BDD::Behave::Formatter::JSON.new;
      my $g = make-group('g');
      my $ex = make-example('held back');
      my $out = capture-formatter-output({
        $f.group-start($g);
        $f.example-skipped($ex);
        $f.run-summary(fake-result(%( total => 1, skipped => 1 )));
      });
      expect($out).to.include('"status":"skipped"');
    }

    it 'records around-each-skipped examples with skip_reason', {
      my $f = BDD::Behave::Formatter::JSON.new;
      my $g = make-group('g');
      my $ex = make-example('held back');
      my $out = capture-formatter-output({
        $f.group-start($g);
        $f.example-around-skipped($ex);
        $f.run-summary(fake-result(%( total => 1, skipped => 1 )));
      });
      expect($out).to.include('"skip_reason":');
      expect($out).to.include('around-each did not invoke continuation');
    }

    it 'derives full_description from auto-description for `it { }` form', {
      my $f = BDD::Behave::Formatter::JSON.new;
      my $g = make-group('Calculator');
      my $ex = make-example('original');
      my $out = capture-formatter-output({
        $f.group-start($g);
        $f.example-start($ex, :auto);
        $f.example-auto-description($ex, :description('derived label'));
        $f.example-pass($ex);
        $f.group-end($g);
        $f.run-summary(fake-result(%( total => 1, passed => 1 )));
      });
      expect($out).to.include('"description":"derived label"');
      expect($out).to.include('"full_description":"Calculator derived label"');
    }

    it 'captures expectation failures attached to the failing example', {
      my $f = BDD::Behave::Formatter::JSON.new;
      my $g = make-group('g');
      my $ex = make-example('broken');
      my $out;
      capture-failures {
        $out = capture-formatter-output({
          $f.group-start($g);
          $f.example-start($ex);
          Failures.list.push: Failure.new(
            :file('spec.raku'), :line(11), :given('a'), :expected('b'),
          );
          $f.example-fail($ex, :failure-info(%( file => 'spec.raku', line => 11 )));
          $f.run-summary(fake-result(%( total => 1, failed => 1 )));
        });
      };
      expect($out).to.include('"expectations":');
      expect($out).to.include('"given":"a"');
      expect($out).to.include('"expected":"b"');
    }
  }

  describe 'silent and suppressed hooks', {
    it 'group hooks update structure but emit no output before summary', {
      my $f = BDD::Behave::Formatter::JSON.new;
      my $g = make-group('g');
      my $out = capture-formatter-output({
        $f.suite-loading(:file('x'));
        my $s = Suite.create(:description('s'), :file('/tmp/x-spec.raku'.IO), :line(1));
        $f.suite-start($s);
        $f.suite-end($s);
        $f.group-start($g);
        $f.group-end($g);
        $f.group-around-skipped($g);
      });
      expect($out).to.eq('');
    }

    it 'profile/memory/benchmark hooks emit nothing', {
      my $f = BDD::Behave::Formatter::JSON.new;
      my $out = capture-formatter-output({
        $f.profile-summary([], :limit(5));
        $f.memory-profile-summary([], :limit(5));
        $f.benchmark-summary-section([], [], :threshold(0.1), :format('text'));
      });
      expect($out).to.eq('');
    }

    it 'example-slow and example-memory-leak emit nothing', {
      my $f = BDD::Behave::Formatter::JSON.new;
      my $ex = make-example('e');
      $ex.duration = 1.0;
      $ex.memory-delta = 999;
      my $out = capture-formatter-output({
        $f.example-slow($ex, :threshold(0.1.Rat));
        $f.example-memory-leak($ex, :threshold(100));
      });
      expect($out).to.eq('');
    }
  }

  describe 'load errors and summary line', {
    it 'records load errors into the document', {
      my $f = BDD::Behave::Formatter::JSON.new;
      my $out = capture-formatter-output({
        $f.load-errors([
          %( file => '/tmp/a.raku', message => 'syntax error' ),
        ]);
        $f.run-summary(fake-result(%( total => 0 )));
      });
      expect($out).to.include('"load_errors":');
      expect($out).to.include('"file":"/tmp/a.raku"');
      expect($out).to.include('"message":"syntax error"');
    }

    it 'summary_line tracks the human-readable counts message', {
      my $f = BDD::Behave::Formatter::JSON.new;
      my $out = capture-formatter-output({
        $f.run-summary(fake-result(%( total => 4, failed => 1, passed => 3 )));
      });
      expect($out).to.include('"summary_line":"4 examples, 1 failed, 3 passed"');
    }
  }
}
