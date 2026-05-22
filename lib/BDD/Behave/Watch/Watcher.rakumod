unit module BDD::Behave::Watch::Watcher;

our class Snapshot {
  has Instant $.mtime is required;
  has Int     $.size  is required;
}

our class Change {
  has IO::Path $.path is required;
  has Str      $.kind is required;
}

our class Watcher {
  has IO::Path @.paths;
  has Mu       $.match = / [ '.rakumod' | '.raku' | '.rakutest' | '.pm6' ] $ /;
  has %!snapshots;
  has Bool     $!initialized = False;

  method add-path(IO::Path $path) {
    @!paths.push: $path;
    $!initialized = False;
    self;
  }

  method scan-files(--> Seq) {
    gather for @!paths -> $root {
      next unless $root.e;
      if $root.f {
        take $root;
      } elsif $root.d {
        self!walk-dir($root);
      }
    }
  }

  method !walk-dir(IO::Path $dir) {
    for $dir.dir -> $entry {
      next if $entry.basename eq '.precomp' | '.git';
      if $entry.f {
        take $entry if !$.match.defined || $entry.basename ~~ $.match;
      } elsif $entry.d {
        self!walk-dir($entry);
      }
    }
  }

  method !current-snapshots(--> Hash) {
    my %snap;
    for self.scan-files() -> $file {
      next unless $file.e;
      my $key = $file.absolute;
      %snap{$key} = Snapshot.new(
        :mtime($file.modified),
        :size($file.s),
      );
    }
    %snap;
  }

  method initialize() {
    %!snapshots  = self!current-snapshots();
    $!initialized = True;
    self;
  }

  method poll(--> List) {
    self.initialize unless $!initialized;
    my %current = self!current-snapshots();
    my @changes;

    for %current.kv -> $path, $snap {
      my $prev = %!snapshots{$path};
      if !$prev.defined {
        @changes.push: Change.new(:path($path.IO), :kind('added'));
      } elsif $prev.mtime != $snap.mtime || $prev.size != $snap.size {
        @changes.push: Change.new(:path($path.IO), :kind('modified'));
      }
    }

    for %!snapshots.keys -> $path {
      next if %current{$path}:exists;
      @changes.push: Change.new(:path($path.IO), :kind('removed'));
    }

    %!snapshots = %current;
    @changes.List;
  }

  method tracked-count(--> Int) {
    %!snapshots.elems;
  }
}
