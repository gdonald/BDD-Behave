
class Files is export {
  my Str $.specs-dir = 'specs';
  my Str $.current;
  my Mu $.test = /'spec.p6' [\: \d+]?$/;

  method list(@args) {
    if @args.elems {
      gather for @args -> $arg { if $arg ~~ $.test { take $arg } }
    } else {
      self.find(Files.specs-dir).sort;
    }
  }

  method find($dir) {
    unless $dir.IO.d {
      say "`$dir` directory not found\n";
      exit 1;
    }

    gather for dir $dir -> $path {
      if $path.basename ~~ $.test { take $path.Str }
      if $path.d                  { .take for self.find($path) };
    }
  }
}
