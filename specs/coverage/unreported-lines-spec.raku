use BDD::Behave;
use BDD::Behave::Coverage;

my $root    = $?FILE.IO.parent.parent.parent;
my $fixture = $root.add('t/fixtures/coverage/UnreportedLines.rakumod');
my $spec    = $root.add('t/fixtures/coverage/unreported-lines-fixture-spec.raku');

sub strip-ansi(Str $text --> Str) {
  $text.subst(/ \e '[' <[0..9;]>* 'm' /, '', :g);
}

sub run-behave-with-coverage(--> Hash) {
  my %env = |%*ENV;
  %env<BEHAVE_DISABLE_CONFIG> = '1';
  %env{$_}:delete for %env.keys.grep(*.starts-with('MVM_COVERAGE'));
  %env<BEHAVE_COVERAGE_LOG>:delete;

  my $proc = run 'raku', "-I{$root.add('lib').absolute}", $root.add('bin/behave').absolute,
    '--coverage', '--coverage-format=text', '--coverage-minimum=100',
    "--coverage-include={$fixture.absolute}", $spec.absolute,
    :out, :err, :env(%env);

  my $out = $proc.out.slurp(:close);
  $proc.err.slurp(:close);

  %( :exit($proc.exitcode), :out(strip-ansi($out)) );
}

describe 'executable lines MoarVM attributes to another line', {
  let(:executable, { BDD::Behave::Coverage::identify-executable-lines($fixture) });

  it 'leaves out a CATCH opener alone on its line', {
    expect(?executable(){4}).to.be-falsy;
  }

  it 'keeps the default block inside the CATCH', {
    expect(?executable(){5}).to.be-truthy;
  }

  it 'leaves out the first pair of a hash literal passed as an argument', {
    expect(?executable(){13}).to.be-falsy;
  }

  it 'keeps the line that opens the hash literal', {
    expect(?executable(){12}).to.be-truthy;
  }
}

describe 'recognizing a pair line', {
  it 'matches a key followed by a fat arrow', {
    expect(BDD::Behave::Coverage::is-pair-line('tenant-id => $tenant.id,')).to.be-truthy;
  }

  it 'does not match an assignment', {
    expect(BDD::Behave::Coverage::is-pair-line('my %h = a => 1;')).to.be-falsy;
  }
}

describe 'recognizing a phaser opener', {
  it 'treats a CONTROL opener alone on its line as declarative', {
    expect(BDD::Behave::Coverage::is-declarative-line('CONTROL {')).to.be-truthy;
  }

  it 'does not treat a CATCH with its body on the same line as declarative', {
    expect(BDD::Behave::Coverage::is-declarative-line('CATCH { default { 1 } }')).to.be-falsy;
  }
}

describe 'a coverage run over a file whose code all runs', {
  let(:coverage-run, { run-behave-with-coverage() });

  it 'reports 100%', {
    expect(coverage-run<out>).to.include('(100.0%)');
  }

  it 'passes a 100% minimum', {
    expect(coverage-run<exit>).to.be(0);
  }
}
