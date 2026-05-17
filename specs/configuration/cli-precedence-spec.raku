use BDD::Behave;

my $root    = $?FILE.IO.parent.parent.parent;
my $bin     = $root.add('bin/behave');
my $passing = $root.add('specs/expectations/be-between-spec.raku');

sub run-behave-with-env(%env, *@args) {
  my $proc = run('raku', '-Ilib', $bin.absolute, |@args,
                 :out, :err, :env(|%*ENV, |%env));
  my $out = $proc.out.slurp(:close);
  my $err = $proc.err.slurp(:close);
  %( :exit($proc.exitcode), :$out, :$err );
}

sub make-tmp-config(Str $body --> IO::Path) {
  my $path = $*TMPDIR.add("behave-cli-precedence-{$*PID}-{(now * 1e6).Int}.behave");
  $path.spurt($body);
  $path;
}

sub strip-ansi(Str $s) { $s.subst(/ \x1b '[' <[0..9;]>+ 'm' /, '', :g) }

describe 'bin/behave configuration precedence', {
  it 'lists --config / --no-config in --help', {
    my %r = run-behave-with-env(%(), '--help');
    expect(%r<exit>).to.be(0);
    expect(%r<out>).to.include('--config PATH');
    expect(%r<out>).to.include('--no-config');
  }

  it 'applies a --config file when given', {
    my $cfg = make-tmp-config(q:to/CONFIG/);
      use BDD::Behave::Configuration;
      configure-behave -> $c {
        $c.format = 'documentation';
      };
    CONFIG
    my %r = run-behave-with-env(
      %(BEHAVE_DISABLE_CONFIG => '1'),
      '--config', $cfg.absolute,
      '--order', 'defined',
      $passing.absolute,
    );
    $cfg.unlink;
    expect(%r<exit>).to.be(0);
    my $clean = strip-ansi(%r<out>);
    expect($clean).to.include('be-between');
    expect($clean).to.not.include('SUCCESS');
  }

  it 'lets CLI --format override a config file', {
    my $cfg = make-tmp-config(q:to/CONFIG/);
      use BDD::Behave::Configuration;
      configure-behave -> $c { $c.format = 'documentation' };
    CONFIG
    my %r = run-behave-with-env(
      %(BEHAVE_DISABLE_CONFIG => '1'),
      '--config', $cfg.absolute,
      '--format', 'progress',
      '--order', 'defined',
      $passing.absolute,
    );
    $cfg.unlink;
    expect(%r<exit>).to.be(0);
    my @lines = strip-ansi(%r<out>).lines.grep(*.chars);
    expect(@lines[0].comb.unique.sort.join).to.eq('.');
  }

  it 'errors when --config path does not exist', {
    my %r = run-behave-with-env(
      %(BEHAVE_DISABLE_CONFIG => '1'),
      '--config', '/tmp/behave-nonexistent-config-PATH-XYZ.behave',
      $passing.absolute,
    );
    expect(%r<exit>).to.eq(2);
    expect(%r<err>).to.include('does not exist');
  }

  it 'BEHAVE_DISABLE_CONFIG=1 disables both default configs', {
    my %r = run-behave-with-env(
      %(BEHAVE_DISABLE_CONFIG => '1'),
      '--order', 'defined',
      $passing.absolute,
    );
    expect(%r<exit>).to.be(0);
  }

  it 'reads include-tag from a config file when no CLI tag is given', {
    my $cfg = make-tmp-config(q:to/CONFIG/);
      use BDD::Behave::Configuration;
      configure-behave -> $c { $c.include-tag('nonexistent-tag-xyz') };
    CONFIG
    my %r = run-behave-with-env(
      %(BEHAVE_DISABLE_CONFIG => '1'),
      '--config', $cfg.absolute,
      '--order', 'defined',
      $passing.absolute,
    );
    $cfg.unlink;
    expect(%r<exit>).to.be(0);
    my $clean = strip-ansi(%r<out>);
    expect($clean).to.include('0 examples');
  }

  it 'CLI --tag and config include-tag both apply (accumulate)', {
    my $cfg = make-tmp-config(q:to/CONFIG/);
      use BDD::Behave::Configuration;
      configure-behave -> $c { $c.include-tag('a') };
    CONFIG
    my %r = run-behave-with-env(
      %(BEHAVE_DISABLE_CONFIG => '1'),
      '--config', $cfg.absolute,
      '--tag', 'b',
      '--order', 'defined',
      $passing.absolute,
    );
    $cfg.unlink;
    my $clean = strip-ansi(%r<out>);
    expect($clean).to.include('0 examples');
  }
}
