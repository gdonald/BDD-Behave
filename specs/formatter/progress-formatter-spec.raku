use lib 'specs/lib';
use BDD::Behave;
use BDD::Behave::Formatter;
use BDD::Behave::Formatter::Tree;
use BDD::Behave::Formatter::Progress;
use BDD::Behave::SpecTree;
use Behave::Test::FakeResult;

constant Suite        = BDD::Behave::SpecTree::Suite;
constant ExampleGroup = BDD::Behave::SpecTree::ExampleGroup;
constant Example      = BDD::Behave::SpecTree::Example;

sub make-group(Str $description) {
  ExampleGroup.new(:$description, :file('synth'.IO), :line(1));
}

sub make-example(Str $description, Bool :$pending = False) {
  Example.new(
    :$description, :file('synth'.IO), :line(1),
    :block({ Nil }), :$pending,
  );
}

sub capture-formatter-output(&block) {
  my $buf = $*TMPDIR.add("progress-fmt-{$*PID}-{(now * 1e6).Int}.out");
  my $fh  = open $buf, :w;
  {
    my $*OUT = $fh;
    block();
  }
  $fh.close;
  my $text = $buf.slurp;
  $buf.unlink;
  $text;
}

sub strip-ansi(Str $s) { $s.subst(/ \x1b '[' <[0..9;]>+ 'm' /, '', :g) }

describe 'BDD::Behave::Formatter::Progress', {
  it 'composes the Formatter role', {
    expect(BDD::Behave::Formatter::Progress.new).to.be-a(BDD::Behave::Formatter);
  }

  it 'inherits from the Tree formatter', {
    expect(BDD::Behave::Formatter::Progress.new).to.be-a(BDD::Behave::Formatter::Tree);
  }

  it 'reports its name as "progress"', {
    expect(BDD::Behave::Formatter::Progress.new.name).to.eq('progress');
  }

  describe 'compact per-example markers', {
    it 'prints a dot for a passing example', {
      my $f  = BDD::Behave::Formatter::Progress.new;
      my $ex = make-example('p');
      my $out = strip-ansi capture-formatter-output({ $f.example-pass($ex) });
      expect($out).to.eq('.');
    }

    it 'prints F for a failing example', {
      my $f  = BDD::Behave::Formatter::Progress.new;
      my $ex = make-example('f');
      my $out = strip-ansi capture-formatter-output({
        $f.example-fail($ex, :failure-info(%(description => 'f')));
      });
      expect($out).to.eq('F');
    }

    it 'prints * for a pending example', {
      my $f  = BDD::Behave::Formatter::Progress.new;
      my $ex = make-example('todo', :pending);
      my $out = strip-ansi capture-formatter-output({ $f.example-pending($ex) });
      expect($out).to.eq('*');
    }

    it 'prints S for a skipped example', {
      my $f  = BDD::Behave::Formatter::Progress.new;
      my $ex = make-example('s');
      my $out = strip-ansi capture-formatter-output({ $f.example-skipped($ex) });
      expect($out).to.eq('S');
    }

    it 'prints S for an around-each-skipped example', {
      my $f  = BDD::Behave::Formatter::Progress.new;
      my $ex = make-example('a');
      my $out = strip-ansi capture-formatter-output({ $f.example-around-skipped($ex) });
      expect($out).to.eq('S');
    }

    it 'prints S for an around-all-skipped group', {
      my $f = BDD::Behave::Formatter::Progress.new;
      my $g = make-group('g');
      my $out = strip-ansi capture-formatter-output({ $f.group-around-skipped($g) });
      expect($out).to.eq('S');
    }

    it 'streams markers in execution order without newlines between them', {
      my $f = BDD::Behave::Formatter::Progress.new;
      my $p = make-example('p');
      my $q = make-example('q');
      my $r = make-example('r', :pending);
      my $out = strip-ansi capture-formatter-output({
        $f.example-pass($p);
        $f.example-fail($q, :failure-info(%(description => 'q')));
        $f.example-pending($r);
      });
      expect($out).to.eq('.F*');
    }
  }

  describe 'silent hooks', {
    it 'suite-loading is silent', {
      my $f   = BDD::Behave::Formatter::Progress.new;
      my $out = capture-formatter-output({ $f.suite-loading(:file('x.raku')) });
      expect($out).to.eq('');
    }

    it 'suite-start is silent even in multi-file mode', {
      my $f     = BDD::Behave::Formatter::Progress.new;
      my $suite = Suite.create(:description('s'), :file('/tmp/a-spec.raku'.IO), :line(1));
      my $out   = capture-formatter-output({
        $f.suite-start($suite);
        $f.suite-start($suite, :multi-file);
      });
      expect($out).to.eq('');
    }

    it 'group-start and group-end are silent', {
      my $f = BDD::Behave::Formatter::Progress.new;
      my $g = make-group('outer');
      my $out = capture-formatter-output({
        $f.group-start($g);
        $f.group-end($g);
      });
      expect($out).to.eq('');
    }

    it 'example-start is silent in both auto and non-auto forms', {
      my $f  = BDD::Behave::Formatter::Progress.new;
      my $ex = make-example('e');
      my $out = capture-formatter-output({
        $f.example-start($ex);
        $f.example-start($ex, :auto);
      });
      expect($out).to.eq('');
    }

    it 'example-auto-description is silent', {
      my $f  = BDD::Behave::Formatter::Progress.new;
      my $ex = make-example('e');
      my $out = capture-formatter-output({
        $f.example-auto-description($ex, :description('derived'));
      });
      expect($out).to.eq('');
    }

    it 'example-slow does not interrupt the dots stream', {
      my $f  = BDD::Behave::Formatter::Progress.new;
      my $ex = make-example('slow');
      $ex.duration = 0.500;
      my $out = capture-formatter-output({
        $f.example-slow($ex, :threshold(0.1.Rat));
      });
      expect($out).to.eq('');
    }

  }

  describe 'summary and run-end output', {
    it 'run-summary still emits the counts line (inherited)', {
      my $f   = BDD::Behave::Formatter::Progress.new;
      my $r   = fake-result(%( total => 4, failed => 1, passed => 3 ));
      my $out = strip-ansi capture-formatter-output({ $f.run-summary($r) });
      expect($out).to.include('4 examples');
      expect($out).to.include('1 failed');
      expect($out).to.include('3 passed');
    }

    it 'run-summary terminates a pending dots stream with a leading newline', {
      my $f = BDD::Behave::Formatter::Progress.new;
      my $r = fake-result(%( total => 2, passed => 2 ));
      my $p = make-example('p');
      my $q = make-example('q');
      my $out = strip-ansi capture-formatter-output({
        $f.example-pass($p);
        $f.example-pass($q);
        $f.run-summary($r);
      });
      my @lines = $out.lines;
      expect(@lines[0]).to.eq('..');
      expect(@lines.grep(*.contains('2 examples')).elems).to.eq(1);
    }

    it 'multi-file-overall still emits the Overall block (inherited)', {
      my $f = BDD::Behave::Formatter::Progress.new;
      my $r = fake-result(%( total => 5, passed => 4, failed => 1 ));
      my $out = strip-ansi capture-formatter-output({
        $f.multi-file-overall($r, :order('defined'));
      });
      expect($out).to.include('Overall: 5 examples');
      expect($out).to.include('=' x 60);
    }

    it 'defers per-file run-summary in multi-file mode so dots stream continuously', {
      my $f  = BDD::Behave::Formatter::Progress.new;
      my $s  = Suite.create(:description('s'), :file('/tmp/a-spec.raku'.IO), :line(1));
      my $p  = make-example('p');
      my $r  = fake-result(%( total => 1, passed => 1 ));
      my $out = strip-ansi capture-formatter-output({
        $f.suite-start($s, :multi-file);
        $f.example-pass($p);
        $f.run-summary($r);
      });
      expect($out).to.eq('.');
      expect($out.contains('1 example')).to.be-falsy;
    }

    it 'emits accumulated failures at multi-file-overall, not per file', {
      my $f  = BDD::Behave::Formatter::Progress.new;
      my $s  = Suite.create(:description('s'), :file('/tmp/a-spec.raku'.IO), :line(1));
      my $r  = fake-result(%( total => 2, failed => 1, passed => 1 ));
      my $out = strip-ansi capture-formatter-output({
        $f.suite-start($s, :multi-file);
        $f.run-summary($r);
        $f.multi-file-overall($r, :order('defined'));
      });
      expect($out).to.include('Overall: 2 examples');
    }

    it 'profile-summary still prints when enabled (inherited)', {
      my $f = BDD::Behave::Formatter::Progress.new;
      my @records = (
        %( description => 'fast', duration => 0.001, example => Any ),
        %( description => 'slow', duration => 0.500, example => Any ),
      );
      my $out = strip-ansi capture-formatter-output({
        $f.profile-summary(@records, :limit(2));
      });
      expect($out).to.include('Top 2 slowest');
      expect($out).to.include('slow');
    }
  }
}
