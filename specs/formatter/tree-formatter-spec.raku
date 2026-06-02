use lib 'specs/lib';
use BDD::Behave;
use BDD::Behave::Formatter;
use BDD::Behave::Formatter::Tree;
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
  my $buf = $*TMPDIR.add("default-fmt-{$*PID}-{(now * 1e6).Int}.out");
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

describe 'BDD::Behave::Formatter::Tree', {
  it 'composes the Formatter role', {
    expect(BDD::Behave::Formatter::Tree.new).to.be-a(BDD::Behave::Formatter);
  }

  it 'reports its name as "tree"', {
    expect(BDD::Behave::Formatter::Tree.new.name).to.eq('tree');
  }

  describe 'group output', {
    it 'prints group description with leading marker', {
      my $f      = BDD::Behave::Formatter::Tree.new;
      my $group  = make-group('outer');
      my $output = capture-formatter-output({ $f.group-start($group) });
      expect($output).to.include("'outer'");
      expect($output).to.include('⮑');
    }

    it 'nests indentation for inner groups', {
      my $f     = BDD::Behave::Formatter::Tree.new;
      my $outer = make-group('outer');
      my $inner = make-group('inner');
      my $out   = capture-formatter-output({
        $f.group-start($outer);
        $f.group-start($inner);
      });
      my @lines = strip-ansi($out).lines;
      expect(@lines[0].starts-with('⮑')).to.be-truthy;
      expect(@lines[1].starts-with('  ⮑')).to.be-truthy;
    }

    it 'unwinds indentation on group-end', {
      my $f     = BDD::Behave::Formatter::Tree.new;
      my $outer = make-group('outer');
      my $inner = make-group('inner');
      my $out   = capture-formatter-output({
        $f.group-start($outer);
        $f.group-start($inner);
        $f.group-end($inner);
        $f.group-end($outer);
        $f.group-start(make-group('next'));
      });
      my @lines = strip-ansi($out).lines;
      expect(@lines[*-1].starts-with('⮑')).to.be-truthy;
    }
  }

  describe 'example output', {
    it 'omits the description line when :auto is true', {
      my $f  = BDD::Behave::Formatter::Tree.new;
      my $ex = make-example('described');
      my $out = capture-formatter-output({ $f.example-start($ex, :auto) });
      expect($out).to.eq('');
    }

    it 'prints SUCCESS for passing examples', {
      my $f  = BDD::Behave::Formatter::Tree.new;
      my $ex = make-example('p');
      my $out = strip-ansi capture-formatter-output({ $f.example-pass($ex) });
      expect($out).to.include('SUCCESS');
    }

    it 'prints FAILURE for failing examples', {
      my $f  = BDD::Behave::Formatter::Tree.new;
      my $ex = make-example('f');
      my $out = strip-ansi capture-formatter-output({
        $f.example-fail($ex, :failure-info(%(description => 'f')));
      });
      expect($out).to.include('FAILURE');
    }

    it 'prints PENDING for pending examples', {
      my $f  = BDD::Behave::Formatter::Tree.new;
      my $ex = make-example('todo', :pending);
      my $out = strip-ansi capture-formatter-output({ $f.example-pending($ex) });
      expect($out).to.include('PENDING');
      expect($out).to.include("'todo'");
    }

    it 'prints SKIPPED for skipped examples', {
      my $f  = BDD::Behave::Formatter::Tree.new;
      my $ex = make-example('s');
      my $out = strip-ansi capture-formatter-output({ $f.example-skipped($ex) });
      expect($out).to.include('SKIPPED');
    }
  }

  describe 'around-each / around-all skipped output', {
    it 'announces around-each skip with the descriptor', {
      my $f  = BDD::Behave::Formatter::Tree.new;
      my $ex = make-example('ax');
      my $out = strip-ansi capture-formatter-output({ $f.example-around-skipped($ex) });
      expect($out).to.include('SKIPPED');
      expect($out).to.include('around-each did not invoke continuation');
    }

    it 'announces around-all skip at the group level', {
      my $f = BDD::Behave::Formatter::Tree.new;
      my $g = make-group('g');
      my $out = strip-ansi capture-formatter-output({ $f.group-around-skipped($g) });
      expect($out).to.include('SKIPPED');
      expect($out).to.include('around-all did not invoke continuation');
    }
  }

  describe 'summary output', {
    it 'emits a counts line that pluralizes correctly', {
      my $f   = BDD::Behave::Formatter::Tree.new;
      my $r   = fake-result(%( total => 3, passed => 3 ));
      my $out = strip-ansi capture-formatter-output({ $f.run-summary($r) });
      expect($out).to.include('3 examples');
      expect($out).to.include('3 passed');
    }

    it 'singularizes the counts line for one example', {
      my $f   = BDD::Behave::Formatter::Tree.new;
      my $r   = fake-result(%( total => 1, passed => 1 ));
      my $out = strip-ansi capture-formatter-output({ $f.run-summary($r) });
      expect($out).to.include('1 example,');
    }

    it 'prints the aborted line when :aborted is true', {
      my $f = BDD::Behave::Formatter::Tree.new;
      my $r = fake-result(%( total => 1, failed => 1 ));
      my $out = strip-ansi capture-formatter-output({
        $f.run-summary($r, :aborted, :fail-fast(1));
      });
      expect($out).to.include('Aborted after 1 failure');
    }

    describe 'seed line', {
      it 'stays silent on a passing random run by default', {
        my $f = BDD::Behave::Formatter::Tree.new;
        my $r = fake-result(%( total => 1, passed => 1 ));

        my $out = strip-ansi capture-formatter-output({
          $f.run-summary($r, :order('random'), :seed(42));
        });
        expect($out.contains('Randomized with seed')).to.be-falsy;
      }

      it 'prints on a passing random run when :show-seed is set', {
        my $f = BDD::Behave::Formatter::Tree.new;
        my $r = fake-result(%( total => 1, passed => 1 ));

        my $out = strip-ansi capture-formatter-output({
          $f.run-summary($r, :order('random'), :seed(42), :show-seed);
        });
        expect($out).to.include('Randomized with seed 42');
      }

      it 'prints on a failing random run even without :show-seed', {
        my $f = BDD::Behave::Formatter::Tree.new;
        my $r = fake-result(%( total => 1, failed => 1 ));

        my $out = strip-ansi capture-formatter-output({
          $f.run-summary($r, :order('random'), :seed(42));
        });
        expect($out).to.include('Randomized with seed 42');
      }

      it 'stays silent under defined order even with :show-seed', {
        my $f = BDD::Behave::Formatter::Tree.new;
        my $r = fake-result(%( total => 1, failed => 1 ));

        my $out = strip-ansi capture-formatter-output({
          $f.run-summary($r, :order('defined'), :seed(42), :show-seed);
        });
        expect($out.contains('Randomized with seed')).to.be-falsy;
      }

      it 'stays silent when the seed is undefined', {
        my $f = BDD::Behave::Formatter::Tree.new;
        my $r = fake-result(%( total => 1, failed => 1 ));

        my $out = strip-ansi capture-formatter-output({
          $f.run-summary($r, :order('random'), :show-seed);
        });
        expect($out.contains('Randomized with seed')).to.be-falsy;
      }
    }
  }

  describe 'profile section', {
    it 'profile-summary stays silent when limit is zero', {
      my $f   = BDD::Behave::Formatter::Tree.new;
      my $out = capture-formatter-output({ $f.profile-summary([], :limit(0)) });
      expect($out).to.eq('');
    }

    it 'profile-summary stays silent when records is empty', {
      my $f   = BDD::Behave::Formatter::Tree.new;
      my $out = capture-formatter-output({ $f.profile-summary([], :limit(5)) });
      expect($out).to.eq('');
    }

    it 'profile-summary prints the top N slowest examples', {
      my $f = BDD::Behave::Formatter::Tree.new;
      my @records = (
        %( description => 'fast', duration => 0.001, example => Any ),
        %( description => 'slow', duration => 0.500, example => Any ),
        %( description => 'mid',  duration => 0.050, example => Any ),
      );
      my $out = strip-ansi capture-formatter-output({
        $f.profile-summary(@records, :limit(2));
      });
      expect($out).to.include('Top 2 slowest');
      expect($out).to.include('slow');
      expect($out).to.include('mid');
      expect($out.contains('fast')).to.be-falsy;
    }
  }

  describe 'multi-file output', {
    it 'multi-file-overall prints the separator and totals', {
      my $f = BDD::Behave::Formatter::Tree.new;
      my $r = FakeResult.new(:total(4), :passed(3), :failed(1));
      my $out = strip-ansi capture-formatter-output({
        $f.multi-file-overall($r, :order('defined'));
      });
      expect($out).to.include('=' x 60);
      expect($out).to.include('Overall: 4 examples');
      expect($out).to.include('1 failed');
      expect($out).to.include('3 passed');
    }

    it 'multi-file-overall stays silent on a passing random run by default', {
      my $f = BDD::Behave::Formatter::Tree.new;
      my $r = FakeResult.new(:total(4), :passed(4));
      my $out = strip-ansi capture-formatter-output({
        $f.multi-file-overall($r, :order('random'), :seed(7));
      });
      expect($out.contains('Randomized with seed')).to.be-falsy;
    }

    it 'multi-file-overall prints the seed on a failing random run', {
      my $f = BDD::Behave::Formatter::Tree.new;
      my $r = FakeResult.new(:total(4), :passed(3), :failed(1));
      my $out = strip-ansi capture-formatter-output({
        $f.multi-file-overall($r, :order('random'), :seed(7));
      });
      expect($out).to.include('Randomized with seed 7');
    }

    it 'multi-file-overall prints the seed when :show-seed is set', {
      my $f = BDD::Behave::Formatter::Tree.new;
      my $r = FakeResult.new(:total(4), :passed(4));
      my $out = strip-ansi capture-formatter-output({
        $f.multi-file-overall($r, :order('random'), :seed(7), :show-seed);
      });
      expect($out).to.include('Randomized with seed 7');
    }

    it 'suite-start in multi-file mode prints the basename', {
      my $f     = BDD::Behave::Formatter::Tree.new;
      my $suite = Suite.create(:description('s'), :file('/tmp/abc-spec.raku'.IO), :line(1));
      my $out   = strip-ansi capture-formatter-output({
        $f.suite-start($suite, :multi-file);
      });
      expect($out).to.include('abc-spec.raku');
    }

    it 'suite-start is silent when :multi-file is false', {
      my $f     = BDD::Behave::Formatter::Tree.new;
      my $suite = Suite.create(:description('s'), :file('/tmp/x.raku'.IO), :line(1));
      my $out   = capture-formatter-output({ $f.suite-start($suite) });
      expect($out).to.eq('');
    }

    it 'load-errors prints nothing when @errors is empty', {
      my $f   = BDD::Behave::Formatter::Tree.new;
      my $out = capture-formatter-output({ $f.load-errors([]) });
      expect($out).to.eq('');
    }

    it 'load-errors prints each error with its message lines', {
      my $f   = BDD::Behave::Formatter::Tree.new;
      my @errs = (
        %( file => '/tmp/a.raku', message => "syntax err\nat line 5" ),
      );
      my $out = strip-ansi capture-formatter-output({ $f.load-errors(@errs) });
      expect($out).to.include('Load errors (1)');
      expect($out).to.include('/tmp/a.raku');
      expect($out).to.include('syntax err');
      expect($out).to.include('at line 5');
    }
  }
}
