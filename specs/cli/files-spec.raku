use BDD::Behave;
use BDD::Behave::Files;

sub make-tree(--> IO::Path) {
  my $root = $*TMPDIR.add("files-{$*PID}-{(now * 1e6).Int}");
  $root.mkdir;
  $root.add('top-spec.raku').spurt: '# top';
  $root.add('helper.raku').spurt:   '# helper, not a spec';
  $root.add('nested').mkdir;
  $root.add('nested').add('inner-spec.raku').spurt: '# inner';
  $root;
}

sub rm-tree($p) {
  for $p.dir -> $entry { $entry.d ?? rm-tree($entry) !! $entry.unlink }
  $p.rmdir;
}

describe 'BDD::Behave::Files.list', {
  it 'returns explicit *-spec.raku args verbatim', {
    my $tree = make-tree;
    my $top = $tree.add('top-spec.raku').absolute;
    my @result = Files.new.list([$top]).List;
    expect(@result.elems).to.eq(1);
    expect(@result[0]).to.eq($top);
    rm-tree($tree);
  }

  it 'expands a directory argument by recursing for *-spec.raku files', {
    my $tree = make-tree;
    my @result = Files.new.list([$tree.absolute]).List.sort;
    expect(@result.elems).to.eq(2);
    expect(@result.join(',').contains('top-spec.raku')).to.be-truthy;
    expect(@result.join(',').contains('inner-spec.raku')).to.be-truthy;
    expect(@result.join(',').contains('helper.raku')).to.be-falsy;
    rm-tree($tree);
  }

  it 'mixes file args and directory args in one call', {
    my $tree = make-tree;
    my $top = $tree.add('top-spec.raku').absolute;
    my $nested = $tree.add('nested').absolute;
    my @result = Files.new.list([$top, $nested]).List;
    expect(@result.elems).to.eq(2);
    expect(@result.join(',').contains('top-spec.raku')).to.be-truthy;
    expect(@result.join(',').contains('inner-spec.raku')).to.be-truthy;
    rm-tree($tree);
  }

  it 'warns to stderr and skips arguments that are neither file nor directory', {
    my $tmp-err = $*TMPDIR.add("files-err-{$*PID}-{(now * 1e6).Int}.err");
    my $eh = open $tmp-err, :w;
    my @result;
    {
      my $*ERR = $eh;
      @result = Files.new.list(['--not-a-file']).List;
    }
    $eh.close;
    my $err-text = $tmp-err.slurp;
    $tmp-err.unlink;
    expect(@result.elems).to.eq(0);
    expect($err-text).to.include('--not-a-file');
    expect($err-text).to.include('not a spec file or directory');
  }

  it 'still auto-discovers from the default specs/ dir when @args is empty', {
    my @result = Files.new.list([]).List;
    expect(@result.elems).to.be-greater-than(0);
    expect(@result.first(*.contains('spec.raku')).defined).to.be-truthy;
  }
}
