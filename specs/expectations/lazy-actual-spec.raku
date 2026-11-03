use BDD::Behave;

sub strip-ansi(Str $text --> Str) {
  $text.subst(/ \e '[' <[0..9;]>* 'm' /, '', :g);
}

describe 'a failing expectation on a list built by a map that calls a let', {
  let(:behave-run, {
    my $root    = $?FILE.IO.parent.parent.parent;
    my $fixture = $root.add('t/fixtures/lazy-actual-fixture-spec.raku');

    my %env = |%*ENV;
    %env<BEHAVE_DISABLE_CONFIG> = '1';

    my $proc = run 'raku', "-I{$root.add('lib').absolute}", $root.add('bin/behave').absolute, $fixture.absolute,
      :out, :err, :env(%env);

    my $out = strip-ansi($proc.out.slurp(:close));
    my $err = $proc.err.slurp(:close);

    %( :exit($proc.exitcode), :$out, :$err );
  });

  it 'reports the values of the list', {
    expect(behave-run()<out>.contains('Expected: (Bool::False, Bool::False)')).to.be-truthy;
  }

  it 'does not report a missing let runtime', {
    expect((behave-run()<out> ~ behave-run()<err>).contains('$*LET-RUNTIME')).to.be-falsy;
  }

  it 'fails the run', {
    expect(behave-run()<exit>).to.be(1);
  }
}
