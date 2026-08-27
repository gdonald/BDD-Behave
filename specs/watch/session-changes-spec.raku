use BDD::Behave;
use BDD::Behave::Watch::Watcher;
use BDD::Behave::Watch::SmartSelector;
use BDD::Behave::Watch::UI;
use BDD::Behave::Watch::Session;

sub fresh-dir(--> IO::Path) {
  my $d = $*TMPDIR.add("behave-session-changes-{$*PID}-{(now * 1e6).Int.base(36)}");
  $d.mkdir;
  $d;
}

sub rm-rf($node) {
  if $node.d {
    rm-rf($_) for $node.dir;
    $node.rmdir if $node.e;
  } else {
    $node.unlink if $node.e;
  }
}

# The UI writes to the null device so a session under test prints nothing, and
# its lines are read back from a string handle where the spec needs them.
sub make-session(
  $dir, @all-specs, &runner,
  Int  :$max-iterations = 1,
  Bool :$capture-output = False,
  # `run` re-snapshots the tree before its first poll, so a file edited before
  # the session starts is part of the baseline. The tick hook stands in for the
  # sleep between polls, which is where an edit lands mid-loop.
  :&on-tick = -> $ {},
) {
  my $lib   = $dir.add('lib');   $lib.mkdir   unless $lib.e;
  my $specs = $dir.add('specs'); $specs.mkdir unless $specs.e;

  my $watcher = BDD::Behave::Watch::Watcher::Watcher.new;
  $watcher.add-path($lib);
  $watcher.add-path($specs);

  my $selector = BDD::Behave::Watch::SmartSelector::Selector.new(:lib-root($lib));

  my $out = $capture-output
    ?? $dir.add('ui-output.txt').open(:w)
    !! open($*SPEC.devnull, :w);

  my $ui = BDD::Behave::Watch::UI::UI.new(:color(False), :out($out));

  BDD::Behave::Watch::Session::Session.new(
    :$watcher, :$selector, :$ui,
    :all-specs(@all-specs.map(*.IO)),
    :&runner,
    :sleep-fn(&on-tick),
    :$max-iterations,
    :running-test-after-initialize(False),
  );
}

describe 'a watch session reacting to a changed file', {
  context 'given a change that maps to a spec file', {
    let(:dir, { fresh-dir() });
    let(:spec-file, {
      my $specs = dir().add('specs');
      $specs.mkdir unless $specs.e;
      my $file = $specs.add('a-spec.raku');
      $file.spurt('');
      $file;
    });
    let(:runs, { [] });

    let(:session, {
      my $file = spec-file();
      my $edited = False;

      make-session(
        dir(), [$file], -> $req { runs().push($req); 0 },
        :max-iterations(3),
        :on-tick(-> $ {
          unless $edited {
            $file.spurt('# touched, and longer than it was');
            $edited = True;
          }
        }),
      );
    });

    before-each { session().run }

    after-each { rm-rf(dir()) }

    it 'runs the spec the change maps to', {
      expect(runs().elems).to.be(1);
    }

    it 'reports what set the run off', {
      expect(runs()[0].reason).to.eq('change detected');
    }

    it 'runs the file that changed', {
      expect(runs()[0].specs[0].basename).to.eq('a-spec.raku');
    }
  }

  context 'given a change that maps to no spec at all', {
    let(:dir, { fresh-dir() });
    let(:runs, { [] });

    let(:session, {
      my $lib = dir().add('lib');
      $lib.mkdir unless $lib.e;
      my $module = $lib.add('Unmapped.rakumod');
      $module.spurt('# first');
      my $edited = False;

      make-session(
        dir(), [], -> $req { runs().push($req); 0 },
        :capture-output,
        :max-iterations(3),
        :on-tick(-> $ {
          unless $edited {
            $module.spurt('# changed, and longer than it was');
            $edited = True;
          }
        }),
      );
    });

    before-each { session().run }

    after-each { rm-rf(dir()) }

    it 'runs nothing', {
      expect(runs().elems).to.be(0);
    }

    it 'says the change mapped to no specs', {
      expect(dir().add('ui-output.txt').slurp).to.include('no specs mapped to these changes');
    }
  }

  context 'given no change at all', {
    let(:dir, { fresh-dir() });
    let(:runs, { [] });

    let(:session, { make-session(dir(), [], -> $req { runs().push($req); 0 }) });

    before-each { session().run }

    after-each { rm-rf(dir()) }

    it 'runs nothing', {
      expect(runs().elems).to.be(0);
    }
  }
}

describe 'a watch session reading a command', {
  let(:dir, { fresh-dir() });
  let(:runs, { [] });

  let(:session, {
    make-session(dir(), [], -> $req { runs().push($req); 0 }, :capture-output);
  });

  after-each { rm-rf(dir()) }

  sub output-after(Str $command) {
    session().ui.submit-command($command);
    session().run;

    dir().add('ui-output.txt').slurp;
  }

  context 'given the help command', {
    it 'prints the prompt', {
      expect(output-after('h')).to.include('press r rerun selection');
    }

    it 'runs nothing', {
      output-after('help');

      expect(runs().elems).to.be(0);
    }
  }

  context 'given a command it does not know', {
    it 'names the command it was given', {
      expect(output-after('zzz')).to.include("unknown command: 'zzz'");
    }

    it 'prints the prompt after complaining', {
      expect(output-after('zzz')).to.include('press r rerun selection');
    }

    it 'runs nothing', {
      output-after('zzz');

      expect(runs().elems).to.be(0);
    }
  }
}

describe 'a watch session that was told to stop', {
  let(:dir, { fresh-dir() });

  after-each { rm-rf(dir()) }

  it 'reports that it stopped', {
    my $session = make-session(dir(), [], -> $req { 0 }, :max-iterations(2));
    $session.ui.submit-command('q');
    $session.run;

    expect($session.stopped).to.be-truthy;
  }

  it 'reports that it did not stop when it simply ran out of iterations', {
    my $session = make-session(dir(), [], -> $req { 0 }, :max-iterations(1));
    $session.run;

    expect($session.stopped).to.be-falsy;
  }
}
