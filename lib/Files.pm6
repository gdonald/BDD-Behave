
class Files {
  my $.current;

  method list {
    my @files = Array.new;
    my @dir = 'specs'.IO;
    while @dir {
      for @dir.pop.dir -> $path {
        @files.push($path.Str);
      }
    }
    @files.sort;
  }
}
