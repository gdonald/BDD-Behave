use BDD::Behave;
use BDD::Behave::Diff;

sub strip-ansi(Str $s --> Str) {
  $s.subst(/\e '[' \d+ 'm'/, '', :g);
}

describe 'array diff', {
  it 'shows a unified-style structural diff', {
    my $out = strip-ansi(render-diff([1, 2, 3, 4], [1, 2, 9, 4]));
    my $expected = "  [\n    1,\n    2,\n-   9,\n+   3,\n    4,\n  ]";
    expect($out).to.be($expected);
  }

  it 'shows added elements with green plus markers', {
    my $out = render-diff([1, 2, 3], [1, 2]);
    expect($out.contains("\e[32m") ?? 1 !! 0).to.be(1);
  }

  it 'shows removed elements with red minus markers', {
    my $out = render-diff([1], [1, 2, 3]);
    expect($out.contains("\e[31m") ?? 1 !! 0).to.be(1);
  }

  it 'renders empty arrays as []', {
    my $out = strip-ansi(render-diff([1], []));
    expect($out).to.be("- []\n+ [\n+   1,\n+ ]");
  }

  it 'reports identical lines as context (no marker)', {
    my $out = strip-ansi(render-diff([1, 2, 3], [1, 9, 3]));
    expect($out.contains("    1,") ?? 1 !! 0).to.be(1);
    expect($out.contains("    3,") ?? 1 !! 0).to.be(1);
  }

  it 'handles arrays of strings', {
    my $out = strip-ansi(render-diff(<a b c>.Array, <a x c>.Array));
    expect($out).to.be("  [\n    \"a\",\n-   \"x\",\n+   \"b\",\n    \"c\",\n  ]");
  }
}
