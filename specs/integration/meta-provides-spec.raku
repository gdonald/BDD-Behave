use BDD::Behave;

sub parse-provides(IO::Path $path) {
  my %out;
  my $in-provides = False;

  for $path.lines -> $line {
    if !$in-provides {
      $in-provides = True if $line ~~ /'"provides"' \s* ':' \s* '{'/;
      next;
    }
    last if $line ~~ /^ \s* '}'/;
    if $line ~~ / '"' (<-["]>+) '"' \s* ':' \s* '"' (<-["]>+) '"' / {
      %out{ ~$0 } = ~$1;
    }
  }
  %out;
}

sub walk-rakumod(IO::Path $dir) {
  gather for $dir.dir -> $entry {
    if $entry.d {
      take $_ for walk-rakumod($entry);
    } elsif $entry.f && $entry.basename.ends-with('.rakumod') {
      take $entry;
    }
  }
}

sub module-name-from-path(IO::Path $path, IO::Path $lib) {
  my $rel = $path.absolute.substr($lib.absolute.chars + 1);
  $rel .= subst(/'.rakumod' $/, '');
  $rel.split('/').join('::');
}

my $repo     = $?FILE.IO.parent.parent.parent.absolute.IO;
my $lib      = $repo.add('lib');
my %provides = parse-provides($repo.add('META6.json'));
my @declared = %provides.keys.sort;
my @on-disk  = walk-rakumod($lib).map({ module-name-from-path($_, $lib) }).sort;

describe 'META6.json provides declarations', {
  for @on-disk -> $module {
    it "declares $module", {
      expect(%provides{$module}:exists).to.be-truthy;
    }
  }

  for @declared -> $module {
    it "$module path exists on disk", {
      my $declared-path = $repo.add(%provides{$module}).absolute.IO;
      expect($declared-path.f).to.be-truthy;
    }
  }
}
