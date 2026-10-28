use BDD::Behave;

my constant MULTI-LINE-SPEC = q:to/END/;
  use BDD::Behave;

  describe 'a group', {
    it 'an example', {
      expect(1).to.eq(1);
    }
  }
  END

my constant SHARED-EXAMPLES-SPEC = q:to/END/;
  use BDD::Behave;

  shared-examples 'a counter', {
    it 'starts at zero', {
      expect(0).to.eq(0);
    }
  };

  describe 'a counter group', {
    it-behaves-like 'a counter';
  }
  END

my constant SHADOWING-LET-SPEC = q:to/END/;
  use BDD::Behave;

  describe 'a group', {
    let(:example, { 42 });

    it 'calls a let named after a DSL sub', {
      example();

      expect(example()).to.eq(42);
    }
  }
  END

sub run-exit-code(Str $source --> Int) {
  my $spec = $*TMPDIR.add("behave-declaration-line-shadow-{$*PID}-{(now * 1e6).Int}-spec.raku");
  $spec.spurt($source);

  my $proc = run(
    'raku', '-Ilib', 'bin/behave', '--no-config', $spec.absolute,
    :out, :err, :cwd($*CWD), :env(|%*ENV, BEHAVE_DISABLE_CONFIG => '1'),
  );
  $proc.out.slurp(:close);
  $proc.err.slurp(:close);

  $spec.unlink;

  $proc.exitcode;
}

sub listed-tree(Str $source --> Str) {
  my $spec = $*TMPDIR.add("behave-declaration-line-{$*PID}-{(now * 1e6).Int}-spec.raku");
  $spec.spurt($source);

  my $proc = run(
    'raku', '-Ilib', 'bin/behave', '--no-config', '--list-examples', '--list-examples-format=json', $spec.absolute,
    :out, :err, :cwd($*CWD), :env(|%*ENV, BEHAVE_DISABLE_CONFIG => '1'),
  );
  my $stdout = $proc.out.slurp(:close);
  $proc.err.slurp(:close);

  $spec.unlink;

  $stdout;
}

sub declared-line(Str $tree, Str $description --> Int) {
  $tree ~~ / '"description":"' $description '","file":"' <-["]>+ '","line":' (\d+) /;

  $0.defined ?? $0.Int !! 0;
}

describe 'the line a node is declared at', {
  let(:tree, { listed-tree(MULTI-LINE-SPEC) });

  it 'is the line of the describe call for a group whose block spans several lines', {
    expect(declared-line(tree, 'a group')).to.be(3);
  }

  it 'is the line of the it call for an example whose block spans several lines', {
    expect(declared-line(tree, 'an example')).to.be(4);
  }
}

describe 'the line of a group that includes shared examples', {
  it 'is the line of the shared-examples call', {
    expect(declared-line(listed-tree(SHARED-EXAMPLES-SPEC), "behaves like 'a counter'")).to.be(3);
  }
}

describe 'a let named after a DSL sub', {
  it 'is called as the let, without the declared line', {
    expect(run-exit-code(SHADOWING-LET-SPEC)).to.be(0);
  }
}
