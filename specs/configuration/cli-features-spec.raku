use BDD::Behave;

my $root  = $?FILE.IO.parent.parent.parent;
my $bin   = $root.add('bin/behave');
my $helper-fixture   = $root.add('t/fixtures/configuration/helper-fixture-spec.raku');
my $hooks-fixture    = $root.add('t/fixtures/configuration/hooks-fixture-spec.raku');
my $meta-fixture     = $root.add('t/fixtures/configuration/metadata-filter-fixture-spec.raku');

sub run-behave-with-env(%env, *@args) {
  my $proc = run('raku', '-Ilib', $bin.absolute, |@args,
                 :out, :err, :env(|%*ENV, |%env));
  my $out = $proc.out.slurp(:close);
  my $err = $proc.err.slurp(:close);
  %( :exit($proc.exitcode), :$out, :$err );
}

sub strip-ansi(Str $s) { $s.subst(/ \x1b '[' <[0..9;]>+ 'm' /, '', :g) }

sub tmp-config(Str $body --> IO::Path) {
  my $path = $*TMPDIR.add("behave-cli-feat-{$*PID}-{(now * 1e6).Int}.behave");
  $path.spurt($body);
  $path;
}

describe 'bin/behave config-driven features', {
  it 'config.include exposes a helper via $*BEHAVE-HELPERS', {
    my $cfg = tmp-config(q:to/CONFIG/);
      use BDD::Behave::Configuration;
      class Greet { method hello { 'hello' } }
      configure-behave -> $c { $c.include(Greet) };
    CONFIG
    my %r = run-behave-with-env(
      %(BEHAVE_DISABLE_CONFIG => '1'),
      '--config', $cfg.absolute,
      '--order', 'defined',
      $helper-fixture.absolute,
    );
    $cfg.unlink;
    expect(%r<exit>).to.be(0);
    my $clean = strip-ansi(%r<out>);
    expect($clean).to.include('1 passed');
  }

  it 'config.before-each fires before every example in the spec', {
    my $log = $*TMPDIR.add("behave-hooks-log-{$*PID}-{(now * 1e6).Int}.txt");
    $log.spurt('');
    my $cfg = tmp-config(qq:to/CONFIG/);
      use BDD::Behave::Configuration;
      my \$log-path = '{$log.absolute}'.IO;
      configure-behave -> \$c \{
        \$c.before-each(\{
          my \$cur = \$log-path.slurp;
          \$log-path.spurt(\$cur ~ "HOOK\\n");
        });
        \$c.after-all(\{
          my \$cur = \$log-path.slurp;
          \$log-path.spurt(\$cur ~ "DONE\\n");
        });
      };
    CONFIG
    my %r = run-behave-with-env(
      %(BEHAVE_DISABLE_CONFIG => '1'),
      '--config', $cfg.absolute,
      '--order', 'defined',
      $hooks-fixture.absolute,
    );
    $cfg.unlink;
    my $contents = $log.slurp;
    $log.unlink;
    expect(%r<exit>).to.be(0);
    expect($contents.lines.grep(* eq 'HOOK').elems).to.eq(2);
    expect($contents.lines.grep(* eq 'DONE').elems).to.eq(1);
  }

  it 'config.filter(:type<unit>) drops non-matching examples', {
    my $cfg = tmp-config(q:to/CONFIG/);
      use BDD::Behave::Configuration;
      configure-behave -> $c { $c.filter(:type<unit>) };
    CONFIG
    my %r = run-behave-with-env(
      %(BEHAVE_DISABLE_CONFIG => '1'),
      '--config', $cfg.absolute,
      '--order', 'defined',
      $meta-fixture.absolute,
    );
    $cfg.unlink;
    expect(%r<exit>).to.be(0);
    my $clean = strip-ansi(%r<out>);
    expect($clean).to.include('2 examples');
    expect($clean).to.include('2 passed');
  }

  it 'config.filter-run-when-matching is dropped when no example matches', {
    my $cfg = tmp-config(q:to/CONFIG/);
      use BDD::Behave::Configuration;
      configure-behave -> $c { $c.filter-run-when-matching(:nonexistent-meta-key) };
    CONFIG
    my %r = run-behave-with-env(
      %(BEHAVE_DISABLE_CONFIG => '1'),
      '--config', $cfg.absolute,
      '--order', 'defined',
      $meta-fixture.absolute,
    );
    $cfg.unlink;
    expect(%r<exit>).to.be(0);
    my $clean = strip-ansi(%r<out>);
    expect($clean).to.include('3 passed');
  }
}
