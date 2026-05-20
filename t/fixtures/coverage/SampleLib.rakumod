unit module SampleLib;

sub greet(Str $name --> Str) is export {
  if $name.chars == 0 {
    'hello stranger';
  } else {
    "hello $name";
  }
}

sub add(Int $a, Int $b --> Int) is export {
  $a + $b;
}

sub never-called() is export {
  my $x = 99;
  $x;
}
