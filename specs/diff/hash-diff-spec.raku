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
    expect($out.contains('"a" => 1')).to.be-truthy;
    expect($out.contains('-   "b" => 3')).to.be-truthy;
    expect($out.contains('+   "b" => 2')).to.be-truthy;
    expect($out.contains('-   "c" => 4')).to.be-truthy;
  }

  it 'sorts keys alphabetically for stable output', {
    my $a = {z => 1, a => 2, m => 3};
    my $b = {z => 1, a => 9, m => 3};
    my $out = strip-ansi(render-diff($a, $b));
    my $a-pos = $out.index('"a"');
    my $m-pos = $out.index('"m"');
    my $z-pos = $out.index('"z"');
    expect($a-pos < $m-pos).to.be-truthy;
    expect($m-pos < $z-pos).to.be-truthy;
  }

  it 'renders empty hashes as {}', {
    my $out = strip-ansi(render-diff({a => 1}, {}));
    expect($out.contains('- {}')).to.be-truthy;
    expect($out.contains('"a" => 1')).to.be-truthy;
  }

  it 'shows context lines for unchanged keys', {
    my $a = {name => 'alice', age => 30, city => 'paris'};
    my $b = {name => 'alice', age => 31, city => 'paris'};
    my $out = strip-ansi(render-diff($a, $b));
    expect($out.contains('    "city" => "paris"')).to.be-truthy;
    expect($out.contains('    "name" => "alice"')).to.be-truthy;
  }

  it 'colorizes diff output with ANSI codes', {
    my $out = render-diff({a => 1}, {a => 2});
    expect($out.contains("\e[31m")).to.be-truthy;
    expect($out.contains("\e[32m")).to.be-truthy;
  }
}
