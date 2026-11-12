use BDD::Behave;
use Behave::Test::ProjectDir;

my $fixtures = $?FILE.IO.parent.parent.parent.add('t/fixtures/worker-config');

my @spec-files = $fixtures.add('first-spec.raku').absolute,
                 $fixtures.add('second-spec.raku').absolute;

my $hook-config = q:to/CONFIG/;
  use BDD::Behave::Configuration;

  configure-behave -> $c {
    $c.before-all({ 'hook.log'.IO.spurt("{%*ENV<BEHAVE_WORKER_INDEX>}\n", :append) });
  };
  CONFIG

my $tag-config = q:to/CONFIG/;
  use BDD::Behave::Configuration;

  configure-behave -> $c { $c.include-tag('fast') };
  CONFIG

sub hook-log-lines(IO::Path $project --> List) {
  my $log = $project.add('hook.log');

  $log.e ?? $log.lines.sort.List !! ();
}

describe 'project config in parallel workers', {
  context 'when the project config sets a before-all hook', {
    let(:project, { make-project(%('.behave' => $hook-config)) });

    after-each { remove-project(project) }

    context 'in isolated mode with two spec files', {
      before-each { run-behave-in(project, '--parallel', '2', '--parallel-mode', 'isolated', |@spec-files) }

      it 'runs the hook once in the worker process for each spec file', {
        expect(hook-log-lines(project).elems).to.eq(2);
      }
    }

    context 'in lpt mode with two workers and two spec files', {
      before-each { run-behave-in(project, '--parallel', '2', '--parallel-mode', 'lpt', |@spec-files) }

      it 'runs the hook in both workers', {
        expect(hook-log-lines(project).join(',')).to.eq('0,1');
      }
    }

    context 'in queue mode with two spec files', {
      before-each { run-behave-in(project, '--parallel', '2', '--parallel-mode', 'queue', |@spec-files) }

      it 'runs the hook in the workers that receive examples', {
        expect(hook-log-lines(project).elems).to.be-greater-than(0);
      }
    }

    context 'when the run skips the project config', {
      before-each { run-behave-in(project, '--no-project-config', '--parallel', '2', |@spec-files) }

      it 'does not run the hook in any worker', {
        expect(hook-log-lines(project).elems).to.eq(0);
      }
    }

    context 'when the run skips all config files', {
      before-each { run-behave-in(project, '--no-config', '--parallel', '2', |@spec-files) }

      it 'does not run the hook in any worker', {
        expect(hook-log-lines(project).elems).to.eq(0);
      }
    }
  }

  context 'when the project config includes a tag and the command line includes another', {
    let(:project, { make-project(%('.behave' => $tag-config)) });

    after-each { remove-project(project) }

    it 'runs the examples matching either tag in the workers', {
      my %result = run-behave-in(project, '--tag', 'slow', '--parallel', '2', |@spec-files);

      expect(%result<out>).to.match(/'Overall: 2 examples'/);
    }
  }
}
