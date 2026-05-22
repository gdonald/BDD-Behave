use BDD::Behave;
use BDD::Behave::Watch::Watcher;
use BDD::Behave::Watch::SmartSelector;
use BDD::Behave::Watch::UI;
use BDD::Behave::Watch::Session;

sub fresh-dir(--> IO::Path) {
  my $d = $*TMPDIR.add("behave-session-spec-{$*PID}-{(now * 1e6).Int.base(36)}");
  $d.mkdir;
  $d;
}

sub rm-rf($node) {
  if $node.d {
    rm-rf($_) for $node.dir;
    $node.rmdir if $node.e;
  } else {
    $node.unlink if $node.e;
  }
}

sub make-session($dir, @all-specs, &runner, Int :$max-iterations = 0) {
  my $lib = $dir.add('lib'); $lib.mkdir unless $lib.e;
  my $specs = $dir.add('specs'); $specs.mkdir unless $specs.e;

  my $watcher = BDD::Behave::Watch::Watcher::Watcher.new;
  $watcher.add-path($lib);
  $watcher.add-path($specs);

  my $selector = BDD::Behave::Watch::SmartSelector::Selector.new(:lib-root($lib));

  my $null = open($*SPEC.devnull, :w);
  my $ui = BDD::Behave::Watch::UI::UI.new(:color(False), :out($null));

  BDD::Behave::Watch::Session::Session.new(
    :$watcher, :$selector, :$ui,
    :all-specs(@all-specs.map(*.IO)),
    :&runner,
    :sleep-fn(-> $ {}),
    :$max-iterations,
  );
}

describe 'BDD::Behave::Watch::Session', {
  it 'runs once at startup', {
    my $dir = fresh-dir();
    LEAVE { rm-rf($dir) }
    my $sp = $dir.add('specs'); $sp.mkdir;
    my $s = $sp.add('a-spec.raku'); $s.spurt('');

    my @inv;
    my $sess = make-session($dir, [$s], -> $r { @inv.push: $r; 0 });
    $sess.run;

    expect(@inv.elems).to.be(1);
    expect(@inv[0].reason).to.be('initial run');
  }

  it 'reruns on the r command', {
    my $dir = fresh-dir();
    LEAVE { rm-rf($dir) }
    my $sp = $dir.add('specs'); $sp.mkdir;
    my $s = $sp.add('a-spec.raku'); $s.spurt('');

    my @inv;
    my $sess = make-session($dir, [$s], -> $r { @inv.push: $r; 0 }, :max-iterations(1));
    $sess.ui.submit-command('r');
    $sess.run;

    expect(@inv.elems).to.be(2);
    expect(@inv[1].reason).to.be('manual rerun');
  }

  it 'reruns every spec on the a command', {
    my $dir = fresh-dir();
    LEAVE { rm-rf($dir) }
    my $sp = $dir.add('specs'); $sp.mkdir;
    my $a = $sp.add('a-spec.raku'); $a.spurt('');
    my $b = $sp.add('b-spec.raku'); $b.spurt('');

    my @inv;
    my $sess = make-session($dir, [$a, $b], -> $r { @inv.push: $r; 0 }, :max-iterations(1));
    $sess.ui.submit-command('a');
    $sess.run;

    expect(@inv[1].specs.elems).to.be(2);
    expect(@inv[1].reason).to.be('rerun all');
  }

  it 'flags only-failures on the f command', {
    my $dir = fresh-dir();
    LEAVE { rm-rf($dir) }
    my $sp = $dir.add('specs'); $sp.mkdir;
    my $s = $sp.add('a-spec.raku'); $s.spurt('');

    my @inv;
    my $sess = make-session($dir, [$s], -> $r { @inv.push: $r; 0 }, :max-iterations(1));
    $sess.ui.submit-command('f');
    $sess.run;

    expect(@inv[1].only-failures).to.be-truthy;
  }

  it 'stops on the q command', {
    my $dir = fresh-dir();
    LEAVE { rm-rf($dir) }
    my $sp = $dir.add('specs'); $sp.mkdir;
    my $s = $sp.add('a-spec.raku'); $s.spurt('');

    my @inv;
    my $sess = make-session($dir, [$s], -> $r { @inv.push: $r; 0 }, :max-iterations(100));
    $sess.ui.submit-command('q');
    $sess.run;

    expect($sess.stopped).to.be-truthy;
  }
}
