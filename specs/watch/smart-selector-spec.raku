use BDD::Behave;
use BDD::Behave::Watch::Watcher;
use BDD::Behave::Watch::SmartSelector;

sub fresh-dir(--> IO::Path) {
  my $d = $*TMPDIR.add("behave-selector-spec-{$*PID}-{(now * 1e6).Int.base(36)}");
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

sub a-change(IO::Path $p, Str $kind = 'modified') {
  BDD::Behave::Watch::Watcher::Change.new(:path($p), :$kind);
}

describe 'BDD::Behave::Watch::SmartSelector', {
  it 'selects a spec file when the spec itself changes', {
    my $dir = fresh-dir();
    LEAVE { rm-rf($dir) }
    my $lib   = $dir.add('lib');     $lib.mkdir;
    my $specs = $dir.add('specs');   $specs.mkdir;
    my $foo   = $specs.add('foo-spec.raku');
    $foo.spurt('it "x", {}');

    my $sel = BDD::Behave::Watch::SmartSelector::Selector.new(:lib-root($lib));
    my @sel = $sel.select-specs([a-change($foo)], [$foo]).list;

    expect(@sel.elems).to.be(1);
    expect(@sel[0]).to.be($foo.absolute);
  }

  it 'selects specs that reference a changed lib module by basename', {
    my $dir = fresh-dir();
    LEAVE { rm-rf($dir) }
    my $lib  = $dir.add('lib'); $lib.mkdir;
    my $widget = $lib.add('Widget.rakumod');
    $widget.spurt('class Widget {}');

    my $specs = $dir.add('specs'); $specs.mkdir;
    my $a = $specs.add('a-spec.raku'); $a.spurt('Widget.new');
    my $b = $specs.add('b-spec.raku'); $b.spurt('Other.new');

    my $sel = BDD::Behave::Watch::SmartSelector::Selector.new(:lib-root($lib));
    my @sel = $sel.select-specs([a-change($widget)], [$a, $b]).list;

    expect(@sel.elems).to.be(1);
    expect(@sel[0]).to.be($a.absolute);
  }

  it 'selects specs that reference a changed module by full module path', {
    my $dir = fresh-dir();
    LEAVE { rm-rf($dir) }
    my $lib  = $dir.add('lib'); $lib.mkdir;
    my $bdd  = $lib.add('BDD'); $bdd.mkdir;
    my $bv   = $bdd.add('Behave'); $bv.mkdir;
    my $mod  = $bv.add('Thing.rakumod');
    $mod.spurt('unit module BDD::Behave::Thing;');

    my $specs = $dir.add('specs'); $specs.mkdir;
    my $a = $specs.add('a-spec.raku');
    $a.spurt('use BDD::Behave::Thing;');
    my $b = $specs.add('b-spec.raku');
    $b.spurt('say "hi"');

    my $sel = BDD::Behave::Watch::SmartSelector::Selector.new(:lib-root($lib));
    my @sel = $sel.select-specs([a-change($mod)], [$a, $b]).list;

    expect(@sel.elems).to.be(1);
    expect(@sel[0]).to.be($a.absolute);
  }

  it 'falls back to all specs when a lib change matches nothing', {
    my $dir = fresh-dir();
    LEAVE { rm-rf($dir) }
    my $lib  = $dir.add('lib'); $lib.mkdir;
    my $orphan = $lib.add('Orphan.rakumod');
    $orphan.spurt('class Orphan {}');

    my $specs = $dir.add('specs'); $specs.mkdir;
    my $a = $specs.add('a-spec.raku'); $a.spurt('say "no Orphan here"');

    my $sel = BDD::Behave::Watch::SmartSelector::Selector.new(:lib-root($lib));
    my @sel = $sel.select-specs([a-change($orphan)], [$a]).list;

    expect(@sel.elems).to.be(1);
    expect(@sel[0]).to.be($a.absolute);
  }

  it 'ignores removed files when selecting', {
    my $dir = fresh-dir();
    LEAVE { rm-rf($dir) }
    my $lib  = $dir.add('lib'); $lib.mkdir;
    my $mod  = $lib.add('Gone.rakumod');
    my $specs = $dir.add('specs'); $specs.mkdir;
    my $a = $specs.add('a-spec.raku'); $a.spurt('Gone.new');

    my $sel = BDD::Behave::Watch::SmartSelector::Selector.new(:lib-root($lib));
    my @sel = $sel.select-specs([a-change($mod, 'removed')], [$a]).list;

    expect(@sel.elems).to.be(0);
  }

  it 'unions selections across multiple changes', {
    my $dir = fresh-dir();
    LEAVE { rm-rf($dir) }
    my $lib  = $dir.add('lib'); $lib.mkdir;
    my $foo  = $lib.add('Foo.rakumod'); $foo.spurt('class Foo {}');
    my $bar  = $lib.add('Bar.rakumod'); $bar.spurt('class Bar {}');

    my $specs = $dir.add('specs'); $specs.mkdir;
    my $fs = $specs.add('foo-spec.raku'); $fs.spurt('Foo.new');
    my $bs = $specs.add('bar-spec.raku'); $bs.spurt('Bar.new');

    my $sel = BDD::Behave::Watch::SmartSelector::Selector.new(:lib-root($lib));
    my @sel = $sel.select-specs(
      [a-change($foo), a-change($bar)],
      [$fs, $bs],
    ).list;

    expect(@sel.elems).to.be(2);
  }
}
