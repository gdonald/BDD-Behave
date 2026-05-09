use BDD::Behave;
use BDD::Behave::Diff;

sub strip-ansi(Str $s --> Str) {
  $s.subst(/\e '[' \d+ 'm'/, '', :g);
}

describe 'nested structure diff', {
  it 'recurses into nested hashes', {
    my $a = {user => {name => 'alice', age => 30}};
    my $b = {user => {name => 'bob',   age => 30}};
    my $out = strip-ansi(render-diff($a, $b));
    expect($out.contains('"user" => {') ?? 1 !! 0).to.be(1);
    expect($out.contains('-     "name" => "bob"') ?? 1 !! 0).to.be(1);
    expect($out.contains('+     "name" => "alice"') ?? 1 !! 0).to.be(1);
    expect($out.contains('      "age" => 30') ?? 1 !! 0).to.be(1);
  }

  it 'recurses into nested arrays', {
    my $a = [[1, 2], [3, 4]];
    my $b = [[1, 2], [3, 9]];
    my $out = strip-ansi(render-diff($a, $b));
    expect($out.contains('-     9,') ?? 1 !! 0).to.be(1);
    expect($out.contains('+     4,') ?? 1 !! 0).to.be(1);
  }

  it 'handles arrays of hashes', {
    my $a = [{name => 'alice'}, {name => 'bob'}];
    my $b = [{name => 'alice'}, {name => 'carol'}];
    my $out = strip-ansi(render-diff($a, $b));
    expect($out.contains('-     "name" => "carol"') ?? 1 !! 0).to.be(1);
    expect($out.contains('+     "name" => "bob"') ?? 1 !! 0).to.be(1);
  }

  it 'handles hashes of arrays', {
    my $a = {tags => [<x y>]};
    my $b = {tags => [<x z>]};
    my $out = strip-ansi(render-diff($a, $b));
    expect($out.contains('-     "z",') ?? 1 !! 0).to.be(1);
    expect($out.contains('+     "y",') ?? 1 !! 0).to.be(1);
  }

  it 'preserves indentation across nesting levels', {
    my $a = {a => {b => {c => 1}}};
    my $b = {a => {b => {c => 2}}};
    my $out = strip-ansi(render-diff($a, $b));
    expect($out.contains('-       "c" => 2') ?? 1 !! 0).to.be(1);
    expect($out.contains('+       "c" => 1') ?? 1 !! 0).to.be(1);
  }
}
