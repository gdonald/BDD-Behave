
class Files is export {
  my Str $.current;
  my Mu $.test = /'spec.p6' [\: \d+]?$/;

  method list(@args) {
    if @args.elems {
      gather for @args -> $arg { if $arg ~~ $.test { take $arg } }
    } else {
      self.find('specs').sort;
    }
  }

  method find($dir) {
    gather for dir $dir -> $path {
      if $path.basename ~~ $.test { take $path.Str }
      if $path.d                  { .take for self.find($path) };
    }
  }
}
