
class Files {
  my $.current;

  method list {
    self.find('specs', :test(/'_spec.p6' $/)).sort;
  }

  method find($dir, Mu :$test) {
    gather for dir $dir -> $path {
      if $path.basename ~~ $test { take $path.Str }
      if $path.d                 { .take for self.find($path, :$test) };
    }
  }
}
