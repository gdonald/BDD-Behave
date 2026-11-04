use BDD::Behave;

my $root    = $?FILE.IO.parent.parent.parent;
my $bin     = $root.add('bin/behave');
my $fixture = $root.add('t/fixtures/undeclared-routine-fixture-spec.raku');

sub run-behave(*@args --> Str) {
  my $proc = run('raku', "-I{$root.add('lib').absolute}", $bin.absolute, |@args, :out, :err,
    :env(%( |%*ENV, BEHAVE_DISABLE_CONFIG => '1' )));

  $proc.out.slurp(:close) ~ $proc.err.slurp(:close);
}

describe 'a spec file that calls an undeclared routine', {
  context 'in a serial run', {
    let(:output, { run-behave($fixture.absolute) });

    it 'reports the undeclared routine', {
      expect(output().contains('Member used at line 5')).to.be-truthy;
    }

    it 'prints no uninitialized value warning with the load error', {
      expect(output().contains('Use of uninitialized value')).to.be-falsy;
    }
  }

  context 'in a parallel run', {
    let(:output, { run-behave('--parallel', '1', $fixture.absolute) });

    it 'reports the undeclared routine', {
      expect(output().contains('Member used at line 5')).to.be-truthy;
    }

    it 'prints no uninitialized value warning with the load error', {
      expect(output().contains('Use of uninitialized value')).to.be-falsy;
    }
  }
}
