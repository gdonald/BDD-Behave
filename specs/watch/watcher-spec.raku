use BDD::Behave;
use BDD::Behave::Watch::Watcher;

sub fresh-dir(--> IO::Path) {
  my $d = $*TMPDIR.add("behave-watcher-spec-{$*PID}-{(now * 1e6).Int.base(36)}");
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

describe 'BDD::Behave::Watch::Watcher', {
  it 'reports a new file as added', {
    my $dir = fresh-dir();
    LEAVE { rm-rf($dir) }
    my $w = BDD::Behave::Watch::Watcher::Watcher.new;
    $w.add-path($dir);
    $w.initialize;

    $dir.add('new.rakumod').spurt('say 1');
    my @changes = $w.poll.list;

    expect(@changes.elems).to.be(1);
    expect(@changes[0].kind).to.be('added');
  }

  it 'reports a touched file as modified', {
    my $dir  = fresh-dir();
    LEAVE { rm-rf($dir) }
    my $file = $dir.add('a.rakumod');
    $file.spurt('one');

    my $w = BDD::Behave::Watch::Watcher::Watcher.new;
    $w.add-path($dir);
    $w.initialize;

    sleep 0.05;
    $file.spurt('two-longer-content');
    my @changes = $w.poll.list;

    expect(@changes.elems).to.be(1);
    expect(@changes[0].kind).to.be('modified');
  }

  it 'reports a deleted file as removed', {
    my $dir  = fresh-dir();
    LEAVE { rm-rf($dir) }
    my $file = $dir.add('rem.rakumod');
    $file.spurt('x');

    my $w = BDD::Behave::Watch::Watcher::Watcher.new;
    $w.add-path($dir);
    $w.initialize;
    $file.unlink;

    my @changes = $w.poll.list;

    expect(@changes.elems).to.be(1);
    expect(@changes[0].kind).to.be('removed');
  }

  it 'walks subdirectories', {
    my $dir  = fresh-dir();
    LEAVE { rm-rf($dir) }
    my $sub  = $dir.add('inner');
    $sub.mkdir;
    $sub.add('deep.rakumod').spurt('x');

    my $w = BDD::Behave::Watch::Watcher::Watcher.new;
    $w.add-path($dir);
    $w.initialize;

    expect($w.tracked-count).to.be(1);
  }

  it 'filters non-matching basenames', {
    my $dir = fresh-dir();
    LEAVE { rm-rf($dir) }
    $dir.add('keep.rakumod').spurt('k');
    $dir.add('skip.txt').spurt('s');

    my $w = BDD::Behave::Watch::Watcher::Watcher.new;
    $w.add-path($dir);
    $w.initialize;

    expect($w.tracked-count).to.be(1);
  }
}
