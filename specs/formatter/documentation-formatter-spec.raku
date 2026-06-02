use lib 'specs/lib';
use BDD::Behave;
use BDD::Behave::Formatter;
use BDD::Behave::Formatter::Tree;
use BDD::Behave::Formatter::Documentation;
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
  my $buf = $*TMPDIR.add("doc-fmt-{$*PID}-{(now * 1e6).Int}.out");
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

describe 'BDD::Behave::Formatter::Documentation', {
  it 'composes the Formatter role', {
    expect(BDD::Behave::Formatter::Documentation.new).to.be-a(BDD::Behave::Formatter);
  }

  it 'inherits from the Tree formatter', {
    expect(BDD::Behave::Formatter::Documentation.new).to.be-a(BDD::Behave::Formatter::Tree);
  }

  it 'reports its name as "documentation"', {
    expect(BDD::Behave::Formatter::Documentation.new.name).to.eq('documentation');
  }

  describe 'group output', {
    it 'prints group description with no marker arrow', {
      my $f     = BDD::Behave::Formatter::Documentation.new;
      my $group = make-group('Calculator');
      my $out   = strip-ansi capture-formatter-output({ $f.group-start($group) });
      expect($out.lines[0]).to.eq('Calculator');
      expect($out.contains("⮑")).to.be-falsy;
      expect($out.contains("'")).to.be-falsy;
    }

    it 'indents nested groups by two spaces per level', {
      my $f     = BDD::Behave::Formatter::Documentation.new;
      my $outer = make-group('outer');
      my $inner = make-group('inner');
      my $out   = strip-ansi capture-formatter-output({
        $f.group-start($outer);
        $f.group-start($inner);
      });
      my @lines = $out.lines;
      expect(@lines[0]).to.eq('outer');
      expect(@lines[1]).to.eq('  inner');
    }

    it 'unwinds indentation on group-end', {
      my $f     = BDD::Behave::Formatter::Documentation.new;
      my $outer = make-group('outer');
      my $inner = make-group('inner');
      my $out   = strip-ansi capture-formatter-output({
        $f.group-start($outer);
        $f.group-start($inner);
        $f.group-end($inner);
        $f.group-end($outer);
        $f.group-start(make-group('next'));
      });
      my @lines = $out.lines;
      expect(@lines[*-1]).to.eq('next');
    }
  }

  describe 'example output', {
    it 'prints the description for a passing example, no SUCCESS marker', {
      my $f  = BDD::Behave::Formatter::Documentation.new;
      my $g  = make-group('group');
      my $ex = make-example('does the thing');
      my $out = strip-ansi capture-formatter-output({
        $f.group-start($g);
        $f.example-pass($ex);
      });
      my @lines = $out.lines;
      expect(@lines[1]).to.eq('  does the thing');
      expect($out.contains('SUCCESS')).to.be-falsy;
    }

    it 'marks failing examples with (FAILED) suffix', {
      my $f  = BDD::Behave::Formatter::Documentation.new;
      my $g  = make-group('g');
      my $ex = make-example('broken');
      my $out = strip-ansi capture-formatter-output({
        $f.group-start($g);
        $f.example-fail($ex, :failure-info(%(description => 'broken')));
      });
      expect($out.lines[1]).to.eq('  broken (FAILED)');
    }

    it 'marks pending examples with (PENDING) suffix', {
      my $f  = BDD::Behave::Formatter::Documentation.new;
      my $g  = make-group('g');
      my $ex = make-example('todo', :pending);
      my $out = strip-ansi capture-formatter-output({
        $f.group-start($g);
        $f.example-pending($ex);
      });
      expect($out.lines[1]).to.eq('  todo (PENDING)');
    }

    it 'marks skipped examples with (SKIPPED) suffix', {
      my $f  = BDD::Behave::Formatter::Documentation.new;
      my $g  = make-group('g');
      my $ex = make-example('held back');
      my $out = strip-ansi capture-formatter-output({
        $f.group-start($g);
        $f.example-skipped($ex);
      });
      expect($out.lines[1]).to.eq('  held back (SKIPPED)');
    }

    it 'marks around-each-skipped examples with continuation hint', {
      my $f  = BDD::Behave::Formatter::Documentation.new;
      my $g  = make-group('g');
      my $ex = make-example('blocked');
      my $out = strip-ansi capture-formatter-output({
        $f.group-start($g);
        $f.example-around-skipped($ex);
      });
      expect($out.lines[1]).to.include('blocked (SKIPPED');
      expect($out.lines[1]).to.include('around-each did not invoke continuation');
    }

    it 'marks around-all-skipped groups with continuation hint', {
      my $f  = BDD::Behave::Formatter::Documentation.new;
      my $g  = make-group('g');
      my $out = strip-ansi capture-formatter-output({
        $f.group-start($g);
        $f.group-around-skipped($g);
      });
      expect($out.lines[1]).to.include('group skipped');
      expect($out.lines[1]).to.include('around-all did not invoke continuation');
    }

    it 'renders the description from example-auto-description for `it { }` form', {
      my $f  = BDD::Behave::Formatter::Documentation.new;
      my $g  = make-group('g');
      my $ex = make-example('e');
      my $out = strip-ansi capture-formatter-output({
        $f.group-start($g);
        $f.example-auto-description($ex, :description('derived description'));
      });
      expect($out.lines[1]).to.eq('  derived description');
    }
  }

  describe 'silent hooks', {
    it 'suite-loading is silent and suite-start is silent in single-file mode', {
      my $f  = BDD::Behave::Formatter::Documentation.new;
      my $s  = Suite.create(:description('s'), :file('/tmp/x-spec.raku'.IO), :line(1));
      my $out = capture-formatter-output({
        $f.suite-loading(:file('x.raku'));
        $f.suite-start($s);
      });
      expect($out).to.eq('');
    }

    it 'suite-start prints the file basename in multi-file mode', {
      my $f  = BDD::Behave::Formatter::Documentation.new;
      my $s  = Suite.create(:description('s'), :file('/tmp/abc-spec.raku'.IO), :line(1));
      my $out = strip-ansi capture-formatter-output({
        $f.suite-start($s, :multi-file);
      });
      expect($out).to.include('abc-spec.raku');
    }

    it 'example-start is silent in both auto and non-auto forms', {
      my $f  = BDD::Behave::Formatter::Documentation.new;
      my $ex = make-example('e');
      my $out = capture-formatter-output({
        $f.example-start($ex);
        $f.example-start($ex, :auto);
      });
      expect($out).to.eq('');
    }

    it 'example-slow does not interrupt the document', {
      my $f  = BDD::Behave::Formatter::Documentation.new;
      my $ex = make-example('e');
      $ex.duration = 1.0;
      my $out = capture-formatter-output({
        $f.example-slow($ex, :threshold(0.1.Rat));
      });
      expect($out).to.eq('');
    }
  }

  describe 'summary output (inherited)', {
    it 'run-summary still emits the counts line', {
      my $f   = BDD::Behave::Formatter::Documentation.new;
      my $r   = fake-result(%( total => 3, passed => 2, failed => 1 ));
      my $out = strip-ansi capture-formatter-output({ $f.run-summary($r) });
      expect($out).to.include('3 examples');
      expect($out).to.include('1 failed');
      expect($out).to.include('2 passed');
    }

    it 'multi-file-overall still emits the Overall block', {
      my $f   = BDD::Behave::Formatter::Documentation.new;
      my $r   = fake-result(%( total => 5, passed => 5 ));
      my $out = strip-ansi capture-formatter-output({
        $f.multi-file-overall($r, :order('defined'));
      });
      expect($out).to.include('Overall: 5 examples');
    }

    it 'defers per-file run-summary in multi-file mode', {
      my $f  = BDD::Behave::Formatter::Documentation.new;
      my $s  = Suite.create(:description('s'), :file('/tmp/a-spec.raku'.IO), :line(1));
      my $g  = make-group('Calc');
      my $ex = make-example('adds');
      my $out = strip-ansi capture-formatter-output({
        $f.suite-start($s, :multi-file);
        $f.group-start($g);
        $f.example-pass($ex);
        $f.group-end($g);
        $f.run-summary(fake-result(%( total => 1, passed => 1 )));
      });
      expect($out).to.include('Calc');
      expect($out).to.include('adds');
      expect($out.contains('1 example,')).to.be-falsy;
    }
  }
}
