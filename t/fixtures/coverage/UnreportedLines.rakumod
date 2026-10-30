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
