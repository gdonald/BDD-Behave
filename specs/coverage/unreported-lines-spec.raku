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
    '--coverage', '--coverage-branch', '--coverage-format=text', '--coverage-minimum=100',
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

  it 'leaves out an elsif line', {
    expect(?executable(){25}).to.be-falsy;
  }

  it 'keeps the body of an elsif', {
    expect(?executable(){26}).to.be-truthy;
  }

  it 'leaves out a colon pair inside a hash literal', {
    expect(?executable(){33}).to.be-falsy;
  }

  it 'leaves out a negated colon pair inside a hash literal', {
    expect(?executable(){35}).to.be-falsy;
  }
}

describe 'branch lines MoarVM attributes to another line', {
  let(:branches, { BDD::Behave::Coverage::identify-branch-lines($fixture) });

  it 'leaves out an elsif line', {
    expect(?branches(){25}).to.be-falsy;
  }

  it 'keeps the if line', {
    expect(?branches(){22}).to.be-truthy;
  }

  it 'leaves out a postfix unless on a continuation line', {
    expect(?branches(){41}).to.be-falsy;
  }

  it 'leaves out a postfix until after a closing brace', {
    expect(?branches(){49}).to.be-falsy;
  }
}

describe 'recognizing a pair line', {
  it 'matches a key followed by a fat arrow', {
    expect(BDD::Behave::Coverage::is-pair-line('tenant-id => $tenant.id,')).to.be-truthy;
  }

  it 'does not match an assignment', {
    expect(BDD::Behave::Coverage::is-pair-line('my %h = a => 1;')).to.be-falsy;
  }

  it 'matches a line starting with a colon pair', {
    expect(BDD::Behave::Coverage::is-pair-line(':presence, length => { max => 255 },')).to.be-truthy;
  }

  it 'matches a line starting with a negated colon pair', {
    expect(BDD::Behave::Coverage::is-pair-line(':!blank,')).to.be-truthy;
  }

  it 'does not match a method call on the topic', {
    expect(BDD::Behave::Coverage::is-pair-line('.say;')).to.be-falsy;
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

  it 'reports every branch covered', {
    expect(coverage-run<out>).to.include('Branches: 1/1 (100.0%)');
  }

  it 'passes a 100% minimum', {
    expect(coverage-run<exit>).to.be(0);
  }
}
