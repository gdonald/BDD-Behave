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
    expect($out.contains('"user" => {')).to.be-truthy;
    expect($out.contains('-     "name" => "bob"')).to.be-truthy;
    expect($out.contains('+     "name" => "alice"')).to.be-truthy;
    expect($out.contains('      "age" => 30')).to.be-truthy;
  }

  it 'recurses into nested arrays', {
    my $a = [[1, 2], [3, 4]];
    my $b = [[1, 2], [3, 9]];
    my $out = strip-ansi(render-diff($a, $b));
    expect($out.contains('-     9,')).to.be-truthy;
    expect($out.contains('+     4,')).to.be-truthy;
  }

  it 'handles arrays of hashes', {
    my $a = [{name => 'alice'}, {name => 'bob'}];
    my $b = [{name => 'alice'}, {name => 'carol'}];
    my $out = strip-ansi(render-diff($a, $b));
    expect($out.contains('-     "name" => "carol"')).to.be-truthy;
    expect($out.contains('+     "name" => "bob"')).to.be-truthy;
  }

  it 'handles hashes of arrays', {
    my $a = {tags => [<x y>]};
    my $b = {tags => [<x z>]};
    my $out = strip-ansi(render-diff($a, $b));
    expect($out.contains('-     "z",')).to.be-truthy;
    expect($out.contains('+     "y",')).to.be-truthy;
  }

  it 'preserves indentation across nesting levels', {
    my $a = {a => {b => {c => 1}}};
    my $b = {a => {b => {c => 2}}};
    my $out = strip-ansi(render-diff($a, $b));
    expect($out.contains('-       "c" => 2')).to.be-truthy;
    expect($out.contains('+       "c" => 1')).to.be-truthy;
  }
}
