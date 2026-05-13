use BDD::Behave;

my $meta-path = $?FILE.IO.parent.parent.parent.absolute.IO.add('META6.json');

sub parse-string-field(IO::Path $path, Str $name) {
  for $path.lines -> $line {
    if $line ~~ / '"' $name '"' \s* ':' \s* '"' (<-["]>+) '"' / {
      return ~$0;
    }
  }
  Str;
}

sub has-key(IO::Path $path, Str $name) {
  for $path.lines -> $line {
    return True if $line ~~ / '"' $name '"' \s* ':' /;
  }
  False;
}

describe 'META6.json file', {
  it 'exists at the project root', {
    expect($meta-path.f).to.be-truthy;
  }

  it 'is non-empty', {
    expect($meta-path.s > 0).to.be-truthy;
  }
}

describe 'META6.json required fields', {
  it 'declares a name', {
    expect(parse-string-field($meta-path, 'name') eq 'BDD::Behave').to.be-truthy;
  }

  it 'declares a version', {
    my $v = parse-string-field($meta-path, 'version');
    expect($v.defined && $v ~~ /^ \d+ '.' \d+ '.' \d+ $/).to.be-truthy;
  }

  it 'declares a description', {
    my $d = parse-string-field($meta-path, 'description');
    expect($d.defined && $d.chars > 0).to.be-truthy;
  }

  it 'declares a perl version', {
    my $p = parse-string-field($meta-path, 'perl');
    expect($p.defined && $p.chars > 0).to.be-truthy;
  }

  it 'declares an authors list', {
    expect(has-key($meta-path, 'authors')).to.be-truthy;
  }

  it 'declares a license', {
    my $l = parse-string-field($meta-path, 'license');
    expect($l.defined && $l.chars > 0).to.be-truthy;
  }

  it 'declares a provides section', {
    expect(has-key($meta-path, 'provides')).to.be-truthy;
  }

  it 'declares depends, build-depends, and test-depends arrays', {
    expect(has-key($meta-path, 'depends')      ).to.be-truthy;
    expect(has-key($meta-path, 'build-depends')).to.be-truthy;
    expect(has-key($meta-path, 'test-depends') ).to.be-truthy;
  }
}
