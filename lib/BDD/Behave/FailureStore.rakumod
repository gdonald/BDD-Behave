unit module BDD::Behave::FailureStore;

our sub default-path(IO::Path :$base = $*CWD --> IO::Path) {
  $base.IO.add('.behave-failures');
}

our sub read-failures(IO::Path $path --> List) {
  return ().List unless $path.defined && $path.e;

  $path.slurp.lines.grep({ .chars && !.starts-with('#') }).List;
}

our sub merge-failures(
  @existing,
  @ran-locations,
  @failure-locations,
  --> List
) {
  my %ran    = @ran-locations.map:     { $_ => True };
  my @result = @existing.grep({ !%ran{$_} });

  @result.append: @failure-locations;

  @result.unique.List;
}

our sub write-failures(
  IO::Path $path,
  @ran-locations,
  @failure-locations,
) {
  my @existing = read-failures($path);
  my @final    = merge-failures(@existing, @ran-locations, @failure-locations);

  my $content = @final.elems ?? @final.join("\n") ~ "\n" !! '';

  $path.spurt: $content;
}
