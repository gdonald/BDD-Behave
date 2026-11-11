unit module UnreportedLines;

sub guarded(--> Str) is export {
  CATCH {
    default { return 'caught' }
  }

  die 'boom';
}

sub build(Int $id --> Hash) is export {
  my %made = make-hash({
    id   => $id,
    name => 'Acme',
  });
  %made
}

sub make-hash(%attrs --> Hash) { %attrs }

sub classify(Int $n --> Str) is export {
  if $n < 0 {
    return 'negative';
  }
  elsif $n == 0 {
    return 'zero';
  }
  'positive'
}

sub rules(--> Hash) is export {
  make-hash({
    :presence,
    length => { max => 63 },
    :!blank,
  })
}

sub refuse-empty(Str $name --> Str) is export {
  return 'a name is required'
    unless $name;
  $name
}

sub count-down(Int $start --> Int) is export {
  my $remaining = $start;
  repeat {
    $remaining--;
  } until $remaining <= 0;
  $remaining
}
