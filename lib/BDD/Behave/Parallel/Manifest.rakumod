unit module BDD::Behave::Parallel::Manifest;

sub write-manifest(IO::Path $path, @locations --> Nil) is export {
  my $fh = $path.open(:w);
  for @locations -> $loc {
    $fh.say($loc);
  }
  $fh.close;
}

sub read-manifest(IO::Path $path --> List) is export {
  return ().List unless $path.e;
  my @lines;
  for $path.lines -> $line {
    my $trimmed = $line.trim;
    next unless $trimmed.chars;
    @lines.push: $trimmed;
  }
  @lines.List;
}

sub files-from-manifest(@locations --> List) is export {
  my %seen;
  my @files;
  for @locations -> $loc {
    my $idx = $loc.rindex(':');
    next unless $idx.defined;
    my $file = $loc.substr(0, $idx);
    unless %seen{$file}:exists {
      %seen{$file} = True;
      @files.push: $file;
    }
  }
  @files.List;
}
