use lib 'specs/lib';
use BDD::Behave;
use BDD::Behave::Failure;
use BDD::Behave::Failures;
use BDD::Behave::Formatter;
use BDD::Behave::Formatter::JUnit;
use BDD::Behave::SpecTree;
use Behave::Test::FakeResult;

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
  my $buf = $*TMPDIR.add("junit-fmt-{$*PID}-{(now * 1e6).Int}.out");
  my $fh  = open $buf, :w;
  { my $*OUT = $fh; block(); }
  $fh.close;
  my $text = $buf.slurp;
  $buf.unlink;
  $text;
}

describe 'BDD::Behave::Formatter::JUnit', {
  it 'composes the Formatter role', {
    expect(BDD::Behave::Formatter::JUnit.new).to.be-a(BDD::Behave::Formatter);
  }

  it 'reports its name as "junit"', {
    expect(BDD::Behave::Formatter::JUnit.new.name).to.eq('junit');
  }

  describe 'document structure', {
    it 'emits XML prolog and a single testsuites root', {
      my $f = BDD::Behave::Formatter::JUnit.new;
      my $s = make-suite('Calc', '/tmp/calc-spec.raku');
      my $out = capture-formatter-output({
        $f.suite-start($s);
        $f.run-summary(fake-result(%( total => 0 )));
      });
      expect($out).to.match(/^^ '<?xml version="1.0" encoding="UTF-8"?>'/);
      expect($out).to.include('<testsuites');
      expect($out).to.include('</testsuites>');
    }

    it 'opens one testsuite per spec file', {
      my $f = BDD::Behave::Formatter::JUnit.new;
      my $a = make-suite('A', '/tmp/a-spec.raku');
      my $b = make-suite('B', '/tmp/b-spec.raku');
      my $out = capture-formatter-output({
        $f.suite-start($a, :multi-file);
        $f.run-summary(fake-result(%( total => 0 )));
        $f.suite-start($b, :multi-file);
        $f.run-summary(fake-result(%( total => 0 )));
        $f.multi-file-overall(fake-result(%( total => 0 )), :order('defined'));
      });
      my @suite-opens = $out.comb(/'<testsuite '/);
      expect(@suite-opens.elems).to.eq(2);
    }

    it 'does not emit per-file in multi-file mode', {
      my $f = BDD::Behave::Formatter::JUnit.new;
      my $s = make-suite('M', '/tmp/m-spec.raku');
      my $out = capture-formatter-output({
        $f.suite-start($s, :multi-file);
        $f.run-summary(fake-result(%( total => 0 )));
      });
      expect($out).to.eq('');
    }

    it 'never emits the document twice', {
      my $f = BDD::Behave::Formatter::JUnit.new;
      my $s = make-suite('S', '/tmp/s-spec.raku');
      my $out = capture-formatter-output({
        $f.suite-start($s);
        $f.run-summary(fake-result(%( total => 0 )));
        $f.run-summary(fake-result(%( total => 0 )));
      });
      expect($out.comb(/'<?xml'/).elems).to.eq(1);
    }
  }

  describe 'testcase rendering', {
    it 'renders a passing example as a self-closing testcase', {
      my $f = BDD::Behave::Formatter::JUnit.new;
      my $s = make-suite('S', '/tmp/s-spec.raku');
      my $g = make-group('Calculator');
      my $ex = make-example('adds', :line(7));
      $ex.duration = 0.001;
      my $out = capture-formatter-output({
        $f.suite-start($s);
        $f.group-start($g);
        $f.example-start($ex);
        $f.example-pass($ex);
        $f.group-end($g);
        $f.run-summary(fake-result(%( total => 1, passed => 1 )));
      });
      expect($out).to.include('classname="Calculator"');
      expect($out).to.include('name="adds"');
      expect($out).to.include('line="7"');
      expect($out).to.match(/'<testcase' .*? '/>'/);
    }

    it 'joins nested classnames with " > "', {
      my $f = BDD::Behave::Formatter::JUnit.new;
      my $s = make-suite('S', '/tmp/s-spec.raku');
      my $outer = make-group('Calculator');
      my $inner = make-group('addition');
      my $ex = make-example('basic');
      my $out = capture-formatter-output({
        $f.suite-start($s);
        $f.group-start($outer);
        $f.group-start($inner);
        $f.example-pass($ex);
        $f.run-summary(fake-result(%( total => 1, passed => 1 )));
      });
      expect($out).to.include('classname="Calculator &gt; addition"');
    }

    it 'renders a failing example with a <failure> child', {
      my $f = BDD::Behave::Formatter::JUnit.new;
      my $s = make-suite('S', '/tmp/s-spec.raku');
      my $g = make-group('g');
      my $ex = make-example('broken');
      my $out;
      capture-failures {
        $out = capture-formatter-output({
          $f.suite-start($s);
          $f.group-start($g);
          $f.example-start($ex);
          Failures.list.push: Failure.new(
            :file('spec.raku'), :line(11), :given('a'), :expected('b'),
          );
          $f.example-fail($ex, :failure-info(%( file => 'spec.raku', line => 11 )));
          $f.run-summary(fake-result(%( total => 1, failed => 1 )));
        });
      };
      expect($out).to.include('<failure');
      expect($out).to.include('type="Expectation"');
      expect($out).to.include('<![CDATA[');
    }

    it 'renders an exception failure as an <error> child', {
      my $f = BDD::Behave::Formatter::JUnit.new;
      my $s = make-suite('S', '/tmp/s-spec.raku');
      my $g = make-group('g');
      my $ex = make-example('boom');
      my $exception;
      try { die 'kaboom'; CATCH { default { $exception = $_ } } }
      my $out = capture-formatter-output({
        $f.suite-start($s);
        $f.group-start($g);
        $f.example-start($ex);
        $f.example-fail($ex, :failure-info(%( file => 'x', line => 1, exception => $exception )));
        $f.run-summary(fake-result(%( total => 1, failed => 1 )));
      });
      expect($out).to.include('<error');
      expect($out).to.include('message="kaboom"');
    }

    it 'renders pending and skipped examples with <skipped>', {
      my $f = BDD::Behave::Formatter::JUnit.new;
      my $s = make-suite('S', '/tmp/s-spec.raku');
      my $g = make-group('g');
      my $pex = make-example('todo', :pending);
      $pex.set-metadata(:pending-reason('not yet'));
      my $sex = make-example('held back');
      my $out = capture-formatter-output({
        $f.suite-start($s);
        $f.group-start($g);
        $f.example-pending($pex);
        $f.example-skipped($sex);
        $f.run-summary(fake-result(%( total => 2, pending => 1, skipped => 1 )));
      });
      expect($out.comb(/'<skipped'/).elems).to.eq(2);
      expect($out).to.include('pending: not yet');
    }

    it 'escapes XML special characters in attribute values', {
      my $f = BDD::Behave::Formatter::JUnit.new;
      my $s = make-suite('Calc<&>', '/tmp/s-spec.raku');
      my $g = make-group('a & b');
      my $ex = make-example('"quoted" <thing>');
      my $out = capture-formatter-output({
        $f.suite-start($s);
        $f.group-start($g);
        $f.example-pass($ex);
        $f.run-summary(fake-result(%( total => 1, passed => 1 )));
      });
      expect($out).to.include('name="Calc&lt;&amp;&gt;"');
      expect($out).to.include('classname="a &amp; b"');
      expect($out).to.include('name="&quot;quoted&quot; &lt;thing&gt;"');
    }
  }

  describe 'aggregate counts', {
    it 'records totals on the testsuites root', {
      my $f = BDD::Behave::Formatter::JUnit.new;
      my $s = make-suite('S', '/tmp/s-spec.raku');
      my $g = make-group('g');
      my $p = make-example('p');
      my $fl = make-example('f');
      my $pd = make-example('pd', :pending);
      my $out = capture-formatter-output({
        $f.suite-start($s);
        $f.group-start($g);
        $f.example-pass($p);
        $f.example-fail($fl, :failure-info(%( file => 'x', line => 1 )));
        $f.example-pending($pd);
        $f.run-summary(fake-result(%( total => 3, passed => 1, failed => 1, pending => 1 )));
      });
      expect($out).to.include('tests="3"');
      expect($out).to.include('failures="1"');
      expect($out).to.include('skipped="1"');
    }
  }
}
