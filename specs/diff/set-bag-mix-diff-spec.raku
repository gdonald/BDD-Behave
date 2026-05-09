use BDD::Behave;
use BDD::Behave::Diff;

sub strip-ansi(Str $s --> Str) {
  $s.subst(/\e '[' \d+ 'm'/, '', :g);
}

describe 'set diff', {
  it 'shows elements only in given as added and only in expected as removed', {
    my $a = set <a b c>;
    my $b = set <a b d>;
    my $out = strip-ansi(render-diff($a, $b));
    expect($out.contains('Set(') ?? 1 !! 0).to.be(1);
    expect($out.contains('-   d,') ?? 1 !! 0).to.be(1);
    expect($out.contains('+   c,') ?? 1 !! 0).to.be(1);
  }

  it 'shows context for shared elements', {
    my $a = set <a b c>;
    my $b = set <a b d>;
    my $out = strip-ansi(render-diff($a, $b));
    expect($out.contains('    a,') ?? 1 !! 0).to.be(1);
    expect($out.contains('    b,') ?? 1 !! 0).to.be(1);
  }

  it 'renders empty sets as Set()', {
    my $a = set <a>;
    my $b = set ();
    my $out = strip-ansi(render-diff($a, $b));
    expect($out.contains('- Set()') ?? 1 !! 0).to.be(1);
  }
}

describe 'bag diff', {
  it 'shows count differences as paired remove/add lines', {
    my $a = bag <a a b>;
    my $b = bag <a b b>;
    my $out = strip-ansi(render-diff($a, $b));
    expect($out.contains('Bag(') ?? 1 !! 0).to.be(1);
    expect($out.contains('-   "a" => 1') ?? 1 !! 0).to.be(1);
    expect($out.contains('+   "a" => 2') ?? 1 !! 0).to.be(1);
  }
}

describe 'mix diff', {
  it 'shows weighted entries with their values', {
    my $a = Mix.new-from-pairs((a => 1.5), (b => 2.0));
    my $b = Mix.new-from-pairs((a => 1.5), (b => 3.0));
    my $out = strip-ansi(render-diff($a, $b));
    expect($out.contains('Mix(') ?? 1 !! 0).to.be(1);
    expect($out.contains('"b" => 2') ?? 1 !! 0).to.be(1);
    expect($out.contains('"b" => 3') ?? 1 !! 0).to.be(1);
  }
}
