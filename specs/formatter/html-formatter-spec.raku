use lib 'specs/lib';
use BDD::Behave;
use BDD::Behave::Failure;
use BDD::Behave::Failures;
use BDD::Behave::Formatter;
use BDD::Behave::Formatter::HTML;
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
  my $buf = $*TMPDIR.add("html-fmt-{$*PID}-{(now * 1e6).Int}.out");
  my $fh  = open $buf, :w;
  { my $*OUT = $fh; block(); }
  $fh.close;
  my $text = $buf.slurp;
  $buf.unlink;
  $text;
}

describe 'BDD::Behave::Formatter::HTML', {
  it 'composes the Formatter role', {
    expect(BDD::Behave::Formatter::HTML.new).to.be-a(BDD::Behave::Formatter);
  }

  it 'reports its name as "html"', {
    expect(BDD::Behave::Formatter::HTML.new.name).to.eq('html');
  }

  describe 'document envelope', {
    it 'emits a complete HTML5 document', {
      my $f = BDD::Behave::Formatter::HTML.new;
      my $out = capture-formatter-output({
        $f.run-summary(fake-result(%( total => 0 )));
      });
      expect($out).to.include('<!DOCTYPE html>');
      expect($out).to.include('<html');
      expect($out).to.include('<head>');
      expect($out).to.include('<title>Behave Test Report</title>');
      expect($out).to.include('<style>');
      expect($out).to.include('<body>');
      expect($out).to.include('</html>');
    }

    it 'never emits the document twice', {
      my $f = BDD::Behave::Formatter::HTML.new;
      my $out = capture-formatter-output({
        $f.run-summary(fake-result(%( total => 0 )));
        $f.run-summary(fake-result(%( total => 0 )));
      });
      expect($out.comb(/'<!DOCTYPE html>'/).elems).to.eq(1);
    }

    it 'does not emit per-file in multi-file mode', {
      my $f = BDD::Behave::Formatter::HTML.new;
      my $s = make-suite('a', '/tmp/a-spec.raku');
      my $out = capture-formatter-output({
        $f.suite-start($s, :multi-file);
        $f.run-summary(fake-result(%( total => 0 )));
      });
      expect($out).to.eq('');
    }

    it 'emits exactly once at multi-file-overall in multi-file mode', {
      my $f = BDD::Behave::Formatter::HTML.new;
      my $s = make-suite('a', '/tmp/a-spec.raku');
      my $out = capture-formatter-output({
        $f.suite-start($s, :multi-file);
        $f.run-summary(fake-result(%( total => 0 )));
        $f.multi-file-overall(fake-result(%( total => 0 )), :order('defined'));
      });
      expect($out.comb(/'<!DOCTYPE html>'/).elems).to.eq(1);
    }
  }

  describe 'summary and metadata', {
    it 'renders the human-readable summary at the top', {
      my $f = BDD::Behave::Formatter::HTML.new;
      my $out = capture-formatter-output({
        $f.run-summary(fake-result(%( total => 3, failed => 1, passed => 2 )));
      });
      expect($out).to.include('3 examples');
      expect($out).to.include('1 failed');
      expect($out).to.include('2 passed');
    }

    it 'flags the summary box with has-failures when failures occurred', {
      my $f = BDD::Behave::Formatter::HTML.new;
      my $out = capture-formatter-output({
        $f.run-summary(fake-result(%( total => 1, failed => 1 )));
      });
      expect($out).to.include('class="summary has-failures"');
    }

    it 'announces the seed when random order is used', {
      my $f = BDD::Behave::Formatter::HTML.new;
      my $out = capture-formatter-output({
        $f.run-summary(fake-result(%( total => 0 )), :order('random'), :seed(42));
      });
      expect($out).to.include('Randomized with seed 42');
    }
  }

  describe 'groups and collapsible nesting', {
    it 'renders groups as <details>/<summary> with open by default', {
      my $f = BDD::Behave::Formatter::HTML.new;
      my $g = make-group('Calculator');
      my $out = capture-formatter-output({
        $f.group-start($g);
        $f.example-pass(make-example('adds'));
        $f.group-end($g);
        $f.run-summary(fake-result(%( total => 1, passed => 1 )));
      });
      expect($out).to.include('<details open class="group">');
      expect($out).to.include('<summary class="group-summary">Calculator</summary>');
      expect($out).to.include('</details>');
    }

    it 'closes nested groups in stack order', {
      my $f = BDD::Behave::Formatter::HTML.new;
      my $out = capture-formatter-output({
        $f.group-start(make-group('outer'));
        $f.group-start(make-group('inner'));
        $f.example-pass(make-example('p'));
        $f.group-end(make-group('inner'));
        $f.group-end(make-group('outer'));
        $f.run-summary(fake-result(%( total => 1, passed => 1 )));
      });
      expect($out.comb(/'<details'/).elems).to.eq(2);
      expect($out.comb(/'</details>'/).elems).to.eq(2);
    }
  }

  describe 'per-example rendering', {
    it 'renders passing examples with the pass class and ✓ marker', {
      my $f = BDD::Behave::Formatter::HTML.new;
      my $g = make-group('g');
      my $ex = make-example('p');
      $ex.duration = 0.001;
      my $out = capture-formatter-output({
        $f.group-start($g);
        $f.example-pass($ex);
        $f.run-summary(fake-result(%( total => 1, passed => 1 )));
      });
      expect($out).to.include('class="example pass"');
      expect($out).to.include('✓');
    }

    it 'renders failing examples with the fail class and a failure-detail block', {
      my $f = BDD::Behave::Formatter::HTML.new;
      my $g = make-group('g');
      my $ex = make-example('broken');
      my $out;
      capture-failures {
        $out = capture-formatter-output({
          $f.group-start($g);
          $f.example-start($ex);
          Failures.list.push: Failure.new(:file('spec.raku'), :line(11), :given('a'), :expected('b'));
          $f.example-fail($ex, :failure-info(%( file => 'spec.raku', line => 11 )));
          $f.run-summary(fake-result(%( total => 1, failed => 1 )));
        });
      };
      expect($out).to.include('class="example fail"');
      expect($out).to.include('class="failure-detail"');
      expect($out).to.include('✗');
    }

    it 'renders pending examples with the pending class and ⏸ marker', {
      my $f = BDD::Behave::Formatter::HTML.new;
      my $g = make-group('g');
      my $ex = make-example('todo', :pending);
      $ex.set-metadata(:pending-reason('not yet'));
      my $out = capture-formatter-output({
        $f.group-start($g);
        $f.example-pending($ex);
        $f.run-summary(fake-result(%( total => 1, pending => 1 )));
      });
      expect($out).to.include('class="example pending"');
      expect($out).to.include('⏸');
      expect($out).to.include('pending: not yet');
    }

    it 'renders skipped examples with the skipped class and ⊘ marker', {
      my $f = BDD::Behave::Formatter::HTML.new;
      my $g = make-group('g');
      my $out = capture-formatter-output({
        $f.group-start($g);
        $f.example-skipped(make-example('held'));
        $f.run-summary(fake-result(%( total => 1, skipped => 1 )));
      });
      expect($out).to.include('class="example skipped"');
      expect($out).to.include('⊘');
    }

    it 'escapes < / > / & / " in descriptions and file paths', {
      my $f = BDD::Behave::Formatter::HTML.new;
      my $g = make-group('a & b');
      my $ex = make-example('"quoted" <thing>');
      my $out = capture-formatter-output({
        $f.group-start($g);
        $f.example-pass($ex);
        $f.run-summary(fake-result(%( total => 1, passed => 1 )));
      });
      expect($out).to.include('a &amp; b');
      expect($out).to.include('&quot;quoted&quot; &lt;thing&gt;');
    }

    it 'derives the description from auto-description before render', {
      my $f = BDD::Behave::Formatter::HTML.new;
      my $g = make-group('g');
      my $ex = make-example('original');
      my $out = capture-formatter-output({
        $f.group-start($g);
        $f.example-start($ex, :auto);
        $f.example-auto-description($ex, :description('derived'));
        $f.example-pass($ex);
        $f.run-summary(fake-result(%( total => 1, passed => 1 )));
      });
      expect($out).to.include('>derived<');
    }
  }

  describe 'load errors', {
    it 'renders load errors in the body', {
      my $f = BDD::Behave::Formatter::HTML.new;
      my $out = capture-formatter-output({
        $f.load-errors([%( file => '/tmp/a.raku', message => 'syntax error' )]);
        $f.run-summary(fake-result(%( total => 0 )));
      });
      expect($out).to.include('class="load-error"');
      expect($out).to.include('/tmp/a.raku');
      expect($out).to.include('syntax error');
    }
  }
}
