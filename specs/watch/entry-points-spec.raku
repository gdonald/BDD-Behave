use BDD::Behave;
use BDD::Behave::Watch;
use BDD::Behave::Watch::Session;

constant RunRequest = BDD::Behave::Watch::Session::RunRequest;

sub make-tree(*@names --> IO::Path) {
  my $base = $*TMPDIR.add("behave-watch-entry-{$*PID}-{(now * 1e6).Int}");
  $base.mkdir;
  $base.add($_).mkdir for @names;
  $base;
}

sub remove-tree(IO::Path $base --> Nil) {
  return unless $base.e;
  for $base.dir -> $entry {
    $entry.rmdir if $entry.d;
    $entry.unlink if $entry.f;
  }
  $base.rmdir;
}

# The runner spawns `bin/behave`, so the argv it builds is inspected through a
# stand-in first argument that reports its own arguments and exits.
sub echo-argv-runner(IO::Path :$failures-path) {
  BDD::Behave::Watch::make-subprocess-runner(
    :base-argv(('raku', '-e', 'spurt %*ENV<BEHAVE_ARGV_RECORD>, @*ARGS.join("\n")')),
    :$failures-path,
  );
}

describe 'the paths watch mode follows by default', {
  context 'given a project with both lib and specs', {
    let(:base, { make-tree('lib', 'specs') });

    after-each { remove-tree(base()) }

    it 'follows both of them', {
      expect(BDD::Behave::Watch::default-paths(:base(base())).map(*.basename).sort.list)
        .to.eq(('lib', 'specs'));
    }
  }

  context 'given a project with only one of them', {
    let(:base, { make-tree('lib') });

    after-each { remove-tree(base()) }

    it 'follows the one that exists', {
      expect(BDD::Behave::Watch::default-paths(:base(base())).map(*.basename).list)
        .to.eq(('lib',));
    }
  }

  context 'given a project with neither', {
    let(:base, { make-tree() });

    after-each { remove-tree(base()) }

    it 'follows nothing', {
      expect(BDD::Behave::Watch::default-paths(:base(base())).elems).to.be(0);
    }
  }
}

describe 'the watcher watch mode builds by default', {
  let(:base, { make-tree('lib', 'specs') });

  after-each { remove-tree(base()) }

  it 'watches every path it was given', {
    my @paths = BDD::Behave::Watch::default-paths(:base(base()));

    expect(BDD::Behave::Watch::default-watcher(@paths).paths.elems).to.be(2);
  }
}

describe 'the selector watch mode builds by default', {
  it 'maps source files under the lib root it was given', {
    my $selector = BDD::Behave::Watch::default-selector(:lib-root('lib'.IO));

    expect($selector.lib-root.basename).to.eq('lib');
  }
}

describe 'the argv the subprocess runner builds', {
  let(:record, {
    $*TMPDIR.add("behave-watch-argv-{$*PID}-{(now * 1e6).Int}");
  });

  after-each {
    my $path = record();
    $path.unlink if $path.e;
  }

  sub argv-for(RunRequest $request, IO::Path :$failures-path --> List) {
    temp %*ENV<BEHAVE_ARGV_RECORD> = record().absolute;

    echo-argv-runner(:$failures-path)($request);

    record().e ?? record().slurp.lines.List !! ().List;
  }

  context 'given a request for two spec files', {
    let(:argv, {
      argv-for(RunRequest.new(
        :reason('changed'),
        :specs(('specs/a-spec.raku'.IO, 'specs/b-spec.raku'.IO)),
      ));
    });

    it 'passes each spec file to the run', {
      expect(argv().grep(*.ends-with('a-spec.raku')).elems).to.be(1);
    }

    it 'passes them all', {
      expect(argv().grep(*.ends-with('-spec.raku')).elems).to.be(2);
    }

    it 'asks for a full run rather than only the failures', {
      expect(argv().grep(* eq '--only-failures').elems).to.be(0);
    }
  }

  context 'given a request for only the failures', {
    let(:argv, {
      argv-for(RunRequest.new(
        :reason('rerun'),
        :specs(('specs/a-spec.raku'.IO,)),
        :only-failures,
      ));
    });

    it 'asks for only the failures', {
      expect(argv().grep(* eq '--only-failures').elems).to.be(1);
    }

    it 'names no failures file when it was given none', {
      expect(argv().grep(* eq '--failures-path').elems).to.be(0);
    }
  }

  context 'given a request for only the failures and a failures file', {
    let(:argv, {
      argv-for(
        RunRequest.new(
          :reason('rerun'),
          :specs(('specs/a-spec.raku'.IO,)),
          :only-failures,
        ),
        :failures-path('.behave-failures'.IO),
      );
    });

    it 'names the failures file', {
      expect(argv().grep(* eq '--failures-path').elems).to.be(1);
    }

    it 'passes the path of the failures file', {
      expect(argv().grep(*.ends-with('.behave-failures')).elems).to.be(1);
    }
  }
}
