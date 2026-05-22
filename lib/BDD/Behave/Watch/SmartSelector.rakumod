unit module BDD::Behave::Watch::SmartSelector;

our class Selector {
  has IO::Path $.lib-root   is required;
  has Mu       $.spec-test  = / 'spec.raku' $ /;

  method select-specs(@changes, @all-specs --> List) {
    my @selected;
    my $changed-source = False;

    for @changes -> $change {
      next if $change.kind eq 'removed';
      my $path = $change.path;
      if $path.basename ~~ $.spec-test {
        my $abs = $path.absolute;
        @selected.push: $abs if @all-specs.first({ $_.IO.absolute eq $abs }).defined;
      } else {
        $changed-source = True;
        for self!specs-mentioning($path, @all-specs) -> $spec {
          @selected.push: $spec;
        }
      }
    }

    if $changed-source && !@selected.elems {
      return @all-specs.map(*.IO.absolute).List;
    }

    @selected.unique.List;
  }

  method !specs-mentioning(IO::Path $source, @specs --> List) {
    my @terms = self.derive-terms($source);
    return ().List unless @terms.elems;

    my @hits;
    for @specs -> $spec {
      my $path = $spec.IO;
      next unless $path.e;
      my $content = $path.slurp;
      @hits.push: $path.absolute if @terms.first({ $content.contains($_) }).defined;
    }
    @hits.List;
  }

  method derive-terms(IO::Path $source --> List) {
    my @terms;

    my $base = $source.basename;
    $base ~~ s/ \. <[a..zA..Z]>+ $ //;
    @terms.push: $base if $base.chars;

    my $rel-str;
    if $!lib-root.defined && $!lib-root.e {
      my $abs       = $source.absolute;
      my $root-abs  = $!lib-root.absolute;
      if $abs.starts-with($root-abs ~ '/') {
        $rel-str = $abs.substr(($root-abs ~ '/').chars);
      }
    }

    if $rel-str.defined {
      my @segs = $rel-str.split('/').grep(*.chars);
      if @segs.elems {
        @segs[*-1] ~~ s/ \. <[a..zA..Z]>+ $ //;
        @terms.push: @segs.join('::') if @segs.elems >= 2;
        for 1 .. @segs.elems - 2 -> $i {
          @terms.push: @segs[$i .. *].join('::');
        }
      }
    }

    @terms.unique.grep(*.chars).List;
  }
}
