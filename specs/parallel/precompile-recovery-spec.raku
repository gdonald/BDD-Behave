use lib $?FILE.IO.parent.parent.add('lib').absolute;

use BDD::Behave;
use Behave::Test::CompilePassStub;

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
  }

  context 'when the pass exceeds the discovery timeout', {
    let(:hung-run, { make-stub-run(:hang, :timeout(1)) });

    it 'kills the pass and recovers the same way a signal death does', {
      LEAVE hung-run.cleanup;
      expect(hung-run.pass-count).to.be(4);
    }
  }

  context 'when the dead pass reported no project lib dirs', {
    let(:unreported-run, { make-stub-run(:crash, :!report-prefixes) });

    it 'stops after the per-file passes rather than rebuilding blind', {
      LEAVE unreported-run.cleanup;
      expect(unreported-run.pass-count).to.be(3);
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
