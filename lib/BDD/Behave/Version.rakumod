use v6.d;

unit module BDD::Behave::Version;

our sub from-meta-file(IO::Path $path --> Str) {
  return Str unless $path.defined && $path.e;

  my $content = $path.slurp;

  if $content ~~ / '"version"' \s* ':' \s* '"' (<-["]>+) '"' / {
    return ~$0;
  }

  Str;
}

our sub from-installed-distribution(--> Str) {
  my $ver;

  try {
    my $spec = CompUnit::DependencySpecification.new(:short-name<BDD::Behave>);
    my $cu   = $*REPO.need($spec);

    if $cu.defined && $cu.distribution.defined {
      my $meta-ver = $cu.distribution.meta<version>;
      $ver = $meta-ver.Str if $meta-ver.defined && $meta-ver.Str.chars;
    }

    CATCH { default { } }
  }

  $ver // Str;
}

our sub from-source-checkout(IO::Path $program-path --> Str) {
  return Str unless $program-path.defined;

  my $dir = $program-path.absolute.IO.parent;

  while $dir.defined && $dir.absolute ne '/' {
    my $meta = $dir.add('META6.json');
    my $ver  = from-meta-file($meta);

    return $ver if $ver.defined;

    $dir = $dir.parent;
  }

  Str;
}

our sub version(IO::Path :$program-path = $*PROGRAM --> Str) {
  my $installed = from-installed-distribution();

  return $installed if $installed.defined;

  my $source = from-source-checkout($program-path);

  return $source if $source.defined;

  'unknown';
}
