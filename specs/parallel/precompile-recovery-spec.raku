use lib $?FILE.IO.parent.parent.add('lib').absolute;

use BDD::Behave;
use BDD::Behave::Formatter;
use BDD::Behave::Parallel;
use Behave::Test::CompilePassStub;

my class QuietFormatter does BDD::Behave::Formatter { }

sub run-parallel-over(:@spec-files, :@discovery-argv, :%base-env, :&progress) {
  run-parallel(ParallelRunOptions.new(
    :worker-count(1),
    :@spec-files,
    :worker-argv(@discovery-argv),
    :@discovery-argv,
    :%base-env,
    :formatter(QuietFormatter.new),
    :&progress,
  ));
}

describe 'the precompile pass', {
  context 'when every file compiles', {
    let(:clean-run, { make-stub-run() });

    it 'builds the whole graph in a single pass', {
      LEAVE clean-run.cleanup;
      expect(clean-run.pass-count).to.be(1);
    }

    it 'leaves the project precompilation cache alone', {
      LEAVE clean-run.cleanup;
      expect(clean-run.precomp-exists).to.be-truthy;
    }

    it 'announces how many spec files it is precompiling', {
      LEAVE clean-run.cleanup;
      expect(clean-run.progress.lines[0]).to.eq('Precompiling 2 spec files');
    }

    it 'prints a numbered and timed line as each spec file loads', {
      LEAVE clean-run.cleanup;
      expect(clean-run.progress.lines[2]).to.eq("  [2/2] {clean-run.spec-files[1]} (0.0s)");
    }

    it 'reports no load error', {
      LEAVE clean-run.cleanup;
      expect(clean-run.stall.defined).to.be-falsy;
    }
  }

  context 'when the pass dies by a signal on an inconsistent cache', {
    let(:crashed-run, { make-stub-run(:crash) });

    it 'clears the reported cache and rebuilds it', {
      LEAVE crashed-run.cleanup;
      expect(crashed-run.precomp-exists).to.be-falsy;
    }

    it 'loads each file alone to learn the project lib dirs, then rebuilds in one pass', {
      LEAVE crashed-run.cleanup;
      expect(crashed-run.pass-count).to.be(4);
    }

    it 'passes every spec file to the rebuild pass', {
      LEAVE crashed-run.cleanup;
      my $rebuild = crashed-run.invocations[*-1];
      expect(crashed-run.spec-files.grep({ $rebuild.contains(.absolute) }).elems).to.be(2);
    }

    it 'times each spec file it loads alone', {
      LEAVE crashed-run.cleanup;
      my $heading = crashed-run.progress.lines.first(:k, 'Loading each spec file alone to find the precompilation caches to clear');
      expect(crashed-run.progress.lines[$heading + 1]).to.eq("  [1/2] {crashed-run.spec-files[0]} (0.0s)");
    }
  }

  context 'when the pass exceeds the discovery timeout', {
    let(:hung-run, { make-stub-run(:hang, :timeout(1)) });

    it 'kills the pass and recovers the same way a signal death does', {
      LEAVE hung-run.cleanup;
      expect(hung-run.pass-count).to.be(4);
    }

    it 'names the spec file the pass was loading and the one before it', {
      LEAVE hung-run.cleanup;
      expect(hung-run.progress.lines).to.include(
        "The precompile pass timed out after 1s while loading {hung-run.spec-files[1]} (loaded after {hung-run.spec-files[0]})"
      );
    }

    it 'reports no load error once the rebuild pass finishes', {
      LEAVE hung-run.cleanup;
      expect(hung-run.stall.defined).to.be-falsy;
    }
  }

  context 'when the rebuild pass also exceeds the discovery timeout', {
    let(:stuck-run, { make-stub-run(:hang-every-union, :timeout(1)) });

    it 'reports a load error for the spec file the rebuild pass was loading', {
      LEAVE stuck-run.cleanup;
      expect(stuck-run.stall<file>).to.eq(stuck-run.spec-files[1].Str);
    }

    it 'says how long the rebuild pass waited and what it loaded before', {
      LEAVE stuck-run.cleanup;
      expect(stuck-run.stall<message>).to.eq(
        "precompile pass timed out after 1s while loading {stuck-run.spec-files[1]} (loaded after {stuck-run.spec-files[0]})"
      );
    }
  }

  context "when a parallel run's rebuild pass also exceeds the discovery timeout", {
    let(:parallel-run, { make-stub-run(:hang-every-union, :parallel-runner(&run-parallel-over), :timeout(1)) });

    it 'stops before discovery with one load error for the spec file it was loading', {
      LEAVE parallel-run.cleanup;
      expect(parallel-run.result.load-errors.map(*<file>).List).to.eq((parallel-run.spec-files[1].absolute,));
    }
  }

  context "when a parallel run's precompile pass finishes", {
    let(:clean-parallel-run, { make-stub-run(:parallel-runner(&run-parallel-over)) });

    it 'announces discovery after the precompile pass', {
      LEAVE clean-parallel-run.cleanup;
      expect(clean-parallel-run.progress.lines).to.include('Discovering examples in 2 spec files');
    }
  }

  context 'when the dead pass reported no project lib dirs', {
    let(:unreported-run, { make-stub-run(:crash, :!report-prefixes) });

    it 'stops after the per-file passes rather than rebuilding blind', {
      LEAVE unreported-run.cleanup;
      expect(unreported-run.pass-count).to.be(3);
    }
  }

  context 'when there is one spec file', {
    let(:single-run, { make-stub-run(:spec-file-count(1)) });

    it 'announces it in the singular', {
      LEAVE single-run.cleanup;
      expect(single-run.progress.lines[0]).to.eq('Precompiling 1 spec file');
    }
  }

  context 'when there are no spec files', {
    let(:empty-run, { make-stub-run(:spec-file-count(0)) });

    it 'runs no subprocess at all', {
      LEAVE empty-run.cleanup;
      expect(empty-run.pass-count).to.be(0);
    }
  }
}
