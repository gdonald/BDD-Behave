use BDD::Behave;
use BDD::Behave::Diff;

sub strip-ansi(Str $s --> Str) {
  $s.subst(/\e '[' \d+ 'm'/, '', :g);
}

describe 'hash diff', {
  it 'shows missing keys with red minus and added keys with green plus', {
    my $given    = {a => 1, b => 2};
    my $expected = {a => 1, b => 3, c => 4};
    my $out      = strip-ansi(render-diff($given, $expected));
    expect($out.contains('"a" => 1') ?? 1 !! 0).to.be(1);
    expect($out.contains('-   "b" => 3') ?? 1 !! 0).to.be(1);
    expect($out.contains('+   "b" => 2') ?? 1 !! 0).to.be(1);
    expect($out.contains('-   "c" => 4') ?? 1 !! 0).to.be(1);
  }

  it 'sorts keys alphabetically for stable output', {
    my $a = {z => 1, a => 2, m => 3};
    my $b = {z => 1, a => 9, m => 3};
    my $out = strip-ansi(render-diff($a, $b));
    my $a-pos = $out.index('"a"');
    my $m-pos = $out.index('"m"');
    my $z-pos = $out.index('"z"');
    expect($a-pos < $m-pos ?? 1 !! 0).to.be(1);
    expect($m-pos < $z-pos ?? 1 !! 0).to.be(1);
  }

  it 'renders empty hashes as {}', {
    my $out = strip-ansi(render-diff({a => 1}, {}));
    expect($out.contains('- {}') ?? 1 !! 0).to.be(1);
    expect($out.contains('"a" => 1') ?? 1 !! 0).to.be(1);
  }

  it 'shows context lines for unchanged keys', {
    my $a = {name => 'alice', age => 30, city => 'paris'};
    my $b = {name => 'alice', age => 31, city => 'paris'};
    my $out = strip-ansi(render-diff($a, $b));
    expect($out.contains('    "city" => "paris"') ?? 1 !! 0).to.be(1);
    expect($out.contains('    "name" => "alice"') ?? 1 !! 0).to.be(1);
  }

  it 'colorizes diff output with ANSI codes', {
    my $out = render-diff({a => 1}, {a => 2});
    expect($out.contains("\e[31m") ?? 1 !! 0).to.be(1);
    expect($out.contains("\e[32m") ?? 1 !! 0).to.be(1);
  }
}
