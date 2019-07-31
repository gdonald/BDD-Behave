
class Files {
  my $.current;

  method list(@args) {
    my Mu $test = /'spec.p6' [\: \d+]?$/;

    if @args.elems {
      gather for @args -> $arg { if $arg ~~ $test { take $arg } }
    } else {
      self.find('specs', :$test).sort;
    }
  }

  method find($dir, Mu :$test) {
    gather for dir $dir -> $path {
      if $path.basename ~~ $test { take $path.Str }
      if $path.d                 { .take for self.find($path, :$test) };
    }
  }
}
