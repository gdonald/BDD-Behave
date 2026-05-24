unit module BDD::Behave::TypeName;

# Strip the `GLOBAL::` prefix Raku attaches to a type's `.^name` when the type
# is declared inside an EVAL invoked from a precompiled module (the path
# specs take through BDD::Behave::SpecLoader). Spec-author-facing messages
# should show the name the user wrote.
our sub short-type-name(Mu $type --> Str) is export {
  $type.^name.subst(/^ 'GLOBAL::' /, '');
}
