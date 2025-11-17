unit module BDD::Behave::DSL;

need BDD::Behave::SpecRegistry;

sub registry() { BDD::Behave::SpecRegistry::registry() }

our proto sub describe(|) is export {*}

our multi sub describe(Str $description, &block) is export {
  my $file = &block.file.IO;
  my $line = &block.line;
  registry().register-group(
    :$description,
    :&block,
    :$file,
    :$line
  );
  Nil;
}

our multi sub describe(*@) is export {
  die "describe expects a description string and a block";
}

our sub context(|c) is export { describe(|c) }

our sub it(Str $description, &block) is export {
  my $file = &block.file.IO;
  my $line = &block.line;
  registry().register-example(
    :$description,
    :&block,
    :$file,
    :$line
  );
  Nil;
}
