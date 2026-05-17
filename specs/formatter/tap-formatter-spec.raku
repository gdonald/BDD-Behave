use BDD::Behave;
use BDD::Behave::Failure;
use BDD::Behave::Failures;
use BDD::Behave::Formatter;
use BDD::Behave::Formatter::TAP;
use BDD::Behave::SpecTree;

constant Suite        = BDD::Behave::SpecTree::Suite;
constant ExampleGroup = BDD::Behave::SpecTree::ExampleGroup;
constant Example      = BDD::Behave::SpecTree::Example;

sub make-suite(Str $description, Str $file = '/tmp/x-spec.raku') {
  Suite.create(:$description, :file($file.IO), :line(1));
}

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
  my $buf = $*TMPDIR.add("tap-fmt-{$*PID}-{(now * 1e6).Int}.out");
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

describe 'BDD::Behave::Formatter::TAP', {
  it 'composes the Formatter role', {
    expect(BDD::Behave::Formatter::TAP.new).to.be-a(BDD::Behave::Formatter);
  }

  it 'reports its name as "tap"', {
    expect(BDD::Behave::Formatter::TAP.new.name).to.eq('tap');
  }

  describe 'envelope', {
    it 'emits TAP version 13 header and 1..N plan line', {
      my $f = BDD::Behave::Formatter::TAP.new;
      my $g = make-group('g');
      my $ex = make-example('only one');
      my $out = capture-formatter-output({
        $f.group-start($g);
        $f.example-pass($ex);
        $f.run-summary(fake-result(%( total => 1, passed => 1 )));
      });
      my @lines = $out.lines.grep(*.chars);
      expect(@lines[0]).to.eq('TAP version 13');
      expect(@lines[1]).to.eq('1..1');
    }

    it 'omits the plan when no examples ran', {
      my $f = BDD::Behave::Formatter::TAP.new;
      my $out = capture-formatter-output({
        $f.run-summary(fake-result(%( total => 0 )));
      });
      expect($out).to.include('1..0');
    }

    it 'does not emit per-file in multi-file mode', {
      my $f = BDD::Behave::Formatter::TAP.new;
      my $s = make-suite('a', '/tmp/a-spec.raku');
      my $out = capture-formatter-output({
        $f.suite-start($s, :multi-file);
        $f.run-summary(fake-result(%( total => 0 )));
      });
      expect($out).to.eq('');
    }

    it 'emits exactly one document, at multi-file-overall in multi-file mode', {
      my $f = BDD::Behave::Formatter::TAP.new;
      my $s = make-suite('a', '/tmp/a-spec.raku');
      my $out = capture-formatter-output({
        $f.suite-start($s, :multi-file);
        $f.run-summary(fake-result(%( total => 0 )));
        $f.multi-file-overall(fake-result(%( total => 0 )), :order('defined'));
      });
      expect($out.comb(/'TAP version 13'/).elems).to.eq(1);
    }

    it 'never emits twice', {
      my $f = BDD::Behave::Formatter::TAP.new;
      my $out = capture-formatter-output({
        $f.run-summary(fake-result(%( total => 0 )));
        $f.run-summary(fake-result(%( total => 0 )));
      });
      expect($out.comb(/'TAP version 13'/).elems).to.eq(1);
    }
  }

  describe 'per-example rendering', {
    it 'renders passing examples as ok N - description', {
      my $f = BDD::Behave::Formatter::TAP.new;
      my $g = make-group('Calculator');
      my $ex = make-example('adds');
      my $out = capture-formatter-output({
        $f.group-start($g);
        $f.example-pass($ex);
        $f.run-summary(fake-result(%( total => 1, passed => 1 )));
      });
      expect($out).to.include('ok 1 - Calculator adds');
    }

    it 'renders failing examples as not ok with a YAML diagnostic block', {
      Failures.list = ();
      my $f = BDD::Behave::Formatter::TAP.new;
      my $g = make-group('g');
      my $ex = make-example('broken');
      my $out = capture-formatter-output({
        $f.group-start($g);
        $f.example-start($ex);
        Failures.list.push: Failure.new(
          :file('spec.raku'), :line(11), :given('a'), :expected('b'),
        );
        $f.example-fail($ex, :failure-info(%( file => 'spec.raku', line => 11 )));
        $f.run-summary(fake-result(%( total => 1, failed => 1 )));
      });
      expect($out).to.include('not ok 1 - g broken');
      expect($out).to.include('  ---');
      expect($out).to.include('  ...');
      expect($out).to.include("got: 'a'");
      expect($out).to.include("expected: 'b'");
      Failures.list = ();
    }

    it 'renders pending examples with a TODO directive', {
      my $f = BDD::Behave::Formatter::TAP.new;
      my $g = make-group('g');
      my $ex = make-example('todo', :pending);
      $ex.set-metadata(:pending-reason('not yet'));
      my $out = capture-formatter-output({
        $f.group-start($g);
        $f.example-pending($ex);
        $f.run-summary(fake-result(%( total => 1, pending => 1 )));
      });
      expect($out).to.include('ok 1 - g todo # TODO not yet');
    }

    it 'renders skipped examples with a SKIP directive', {
      my $f = BDD::Behave::Formatter::TAP.new;
      my $g = make-group('g');
      my $ex = make-example('held back');
      my $out = capture-formatter-output({
        $f.group-start($g);
        $f.example-skipped($ex);
        $f.run-summary(fake-result(%( total => 1, skipped => 1 )));
      });
      expect($out).to.include('ok 1 - g held back # SKIP skipped');
    }

    it 'renders around-each-skipped examples with a SKIP directive', {
      my $f = BDD::Behave::Formatter::TAP.new;
      my $g = make-group('g');
      my $ex = make-example('aborted');
      my $out = capture-formatter-output({
        $f.group-start($g);
        $f.example-around-skipped($ex);
        $f.run-summary(fake-result(%( total => 1, skipped => 1 )));
      });
      expect($out).to.include('# SKIP around-each did not invoke continuation');
    }

    it 'escapes embedded # in descriptions so it cannot be mistaken for a directive', {
      my $f = BDD::Behave::Formatter::TAP.new;
      my $g = make-group('g');
      my $ex = make-example('tag #foo edge case');
      my $out = capture-formatter-output({
        $f.group-start($g);
        $f.example-pass($ex);
        $f.run-summary(fake-result(%( total => 1, passed => 1 )));
      });
      expect($out).to.include('\\#foo');
    }

    it 'renders exception failures with severity error', {
      my $f = BDD::Behave::Formatter::TAP.new;
      my $g = make-group('g');
      my $ex = make-example('boom');
      my $exception;
      try { die 'kaboom'; CATCH { default { $exception = $_ } } }
      my $out = capture-formatter-output({
        $f.group-start($g);
        $f.example-start($ex);
        $f.example-fail($ex, :failure-info(%( file => 'x', line => 1, exception => $exception )));
        $f.run-summary(fake-result(%( total => 1, failed => 1 )));
      });
      expect($out).to.include("severity: 'error'");
      expect($out).to.include('kaboom');
    }
  }

  describe 'numbering and totals', {
    it 'numbers entries sequentially across all groups', {
      my $f = BDD::Behave::Formatter::TAP.new;
      my $g = make-group('g');
      my $out = capture-formatter-output({
        $f.group-start($g);
        $f.example-pass(make-example('a'));
        $f.example-pass(make-example('b'));
        $f.example-pass(make-example('c'));
        $f.run-summary(fake-result(%( total => 3, passed => 3 )));
      });
      expect($out).to.include('1..3');
      expect($out).to.include('ok 1 - g a');
      expect($out).to.include('ok 2 - g b');
      expect($out).to.include('ok 3 - g c');
    }
  }
}
