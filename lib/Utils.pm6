class Utils {

  method specs {
    my @files = Array.new;
    my @dir = 'specs'.IO;
    while @dir {
      for @dir.pop.dir -> $path {
        @files.push($path.Str);
      }
    }
    @files;
  }
}
