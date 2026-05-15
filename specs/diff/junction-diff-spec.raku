use BDD::Behave;
use BDD::Behave::Diff;

sub strip-ansi(Str $s --> Str) {
  $s.subst(/\e '[' \d+ 'm'/, '', :g);
}

multi sub bare-is-junction(Junction:D --> Bool) { True }
multi sub bare-is-junction($          --> Bool) { False }

describe 'is-junction', {
  it 'detects junctions without autothreading', {
    expect(is-junction(1 | 2 | 3)).to.be-truthy;
    expect(is-junction(1 & 2)).to.be-truthy;
    expect(is-junction(1 ^ 2)).to.be-truthy;
    expect(is-junction(none(1, 2))).to.be-truthy;
  }

  it 'returns False for non-junctions', {
    expect(is-junction(42)).to.be-falsy;
    expect(is-junction('hi')).to.be-falsy;
    expect(is-junction(Nil)).to.be-falsy;
    expect(is-junction([1, 2])).to.be-falsy;
  }
}

describe 'diffable with junctions', {
  it 'returns True when expected is any/all/one/none', {
    expect(diffable(5, 1 | 2 | 3)).to.be-truthy;
    expect(diffable(5, 1 & 2)).to.be-truthy;
    expect(diffable(5, 1 ^ 2 ^ 3)).to.be-truthy;
    expect(diffable(5, none(1, 2, 3))).to.be-truthy;
  }

  it 'returns True even when given is undefined', {
    expect(diffable(Nil, 1 | 2 | 3)).to.be-truthy;
  }
}

describe 'junction-kind', {
  it 'detects each junction kind', {
    expect(junction-kind(1 | 2)).to.be('any');
    expect(junction-kind(1 & 2)).to.be('all');
    expect(junction-kind(1 ^ 2)).to.be('one');
    expect(junction-kind(none(1, 2))).to.be('none');
  }
}

describe 'render-diff with any junction', {
  it 'marks all alternatives as failed when nothing matched', {
    my $out = strip-ansi(render-diff(5, 1 | 2 | 3));
    expect($out).to.include('Alternatives (none of 3 matched; expected at least one):');
    expect($out).to.include('✗ 1');
    expect($out).to.include('✗ 2');
    expect($out).to.include('✗ 3');
  }

  it 'shows the junction gist and the given value', {
    my $out = strip-ansi(render-diff(5, 1 | 2 | 3));
    expect($out).to.start-with('- any(1, 2, 3)');
    expect($out).to.include('+ 5');
  }

  it 'colorizes failing alternatives in red', {
    my $out = render-diff(5, 1 | 2 | 3);
    expect($out.contains("\e[31m")).to.be-truthy;
  }

  it 'renders type-object alternatives via .raku', {
    my $out = strip-ansi(render-diff('hi', Int | Rat));
    expect($out).to.include('✗ Int');
    expect($out).to.include('✗ Rat');
  }
}

describe 'render-diff with all junction', {
  it 'marks individual constituents with their match status', {
    my $out = strip-ansi(render-diff('hi', Int & Str));
    expect($out).to.include('1 of 2 matched');
    expect($out).to.include('✗ Int');
    expect($out).to.include('✓ Str');
  }

  it 'colorizes matched alternatives in green', {
    my $out = render-diff('hi', Int & Str);
    expect($out.contains("\e[32m")).to.be-truthy;
  }

  it 'shows zero matched when nothing matches', {
    my $out = strip-ansi(render-diff('hi', Int & Numeric));
    expect($out).to.include('0 of 2 matched');
  }
}

describe 'render-diff with one junction', {
  it 'shows count when more than one matched', {
    my $out = strip-ansi(render-diff(2, 2 ^ 2 ^ 3));
    expect($out).to.include('2 of 3 matched');
    expect($out).to.include('expected exactly one');
  }

  it 'shows zero count when nothing matched', {
    my $out = strip-ansi(render-diff(5, 1 ^ 2 ^ 3));
    expect($out).to.include('0 of 3 matched');
  }
}

describe 'render-diff with none junction', {
  it 'shows which alternative matched', {
    my $out = strip-ansi(render-diff(2, none(1, 2, 3)));
    expect($out).to.include('1 of 3 matched');
    expect($out).to.include('expected zero');
    expect($out).to.include('✓ 2');
    expect($out).to.include('✗ 1');
    expect($out).to.include('✗ 3');
  }
}

describe 'render-diff under negation', {
  it 'reports any-junction negation as expected-none', {
    my $out = strip-ansi(render-diff(2, 1 | 2 | 3, :negated));
    expect($out).to.include('1 of 3 matched');
    expect($out).to.include('expected none under negation');
  }

  it 'reports none-junction negation as expected-at-least-one', {
    my $out = strip-ansi(render-diff(5, none(1, 2, 3), :negated));
    expect($out).to.include('0 of 3 matched');
    expect($out).to.include('expected at least one under negation');
  }

  it 'reports all-junction negation as expected-fail under negation', {
    my $out = strip-ansi(render-diff(5, Int & Numeric, :negated));
    expect($out).to.include('2 of 2 matched');
    expect($out).to.include('expected at least one to fail under negation');
  }

  it 'reports one-junction negation', {
    my $out = strip-ansi(render-diff(2, 1 ^ 2 ^ 3, :negated));
    expect($out).to.include('expected zero or more than one under negation');
  }
}
