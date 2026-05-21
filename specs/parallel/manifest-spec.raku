use BDD::Behave;
use BDD::Behave::Parallel::Manifest;

describe 'BDD::Behave::Parallel::Manifest', {
  let(:tmp-path, { $*TMPDIR.add("behave-manifest-spec-{$*PID}-{(now * 1e6).Int}.txt") });

  after-each {
    my $p = $*LET-RUNTIME.value('tmp-path');
    $p.unlink if $p.e;
  }

  it 'round-trips a list of FILE:LINE locations', {
    my $p = $*LET-RUNTIME.value('tmp-path');
    my @locs = </abs/x.raku:1 /abs/x.raku:10 /abs/y.raku:5>;
    write-manifest($p, @locs);
    expect(read-manifest($p).Array).to.eq(@locs.Array);
  }

  it 'returns an empty list for a missing manifest', {
    my $missing = $*TMPDIR.add("behave-missing-{$*PID}.txt");
    $missing.unlink if $missing.e;
    expect(read-manifest($missing).elems).to.be(0);
  }

  it 'strips blank lines from the manifest', {
    my $p = $*LET-RUNTIME.value('tmp-path');
    $p.spurt("/a:1\n\n/a:2\n\n/b:3\n");
    expect(read-manifest($p).elems).to.be(3);
  }

  it 'files-from-manifest dedupes preserving first-seen order', {
    my @locs = </abs/a.raku:1 /abs/b.raku:2 /abs/a.raku:5 /abs/c.raku:3>;
    my @files = files-from-manifest(@locs);
    expect(@files.Array).to.eq(</abs/a.raku /abs/b.raku /abs/c.raku>.Array);
  }
}
