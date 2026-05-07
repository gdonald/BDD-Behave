unit module BDD::Behave::SpecRegistry;

need BDD::Behave::SpecTree;

sub suite-type() { ::('BDD::Behave::SpecTree::Suite') }
sub example-group-type() { ::('BDD::Behave::SpecTree::ExampleGroup') }
sub example-type() { ::('BDD::Behave::SpecTree::Example') }

class Entry {
  has $.suite;
  has @.stack;
}

class SpecRegistry {
  has %.entries;
  has $.current-entry is rw;

  method entry-for(IO::Path $file --> Entry) {
    my IO::Path $path = $file.absolute.IO;
    my $key = $path.absolute.Str;
    %.entries{$key} //= Entry.new(
      suite => suite-type().create(:description($path.basename), :file($path)),
      stack => [],
    );
    %.entries{$key};
  }

  method suite-for(IO::Path $file) {
    self.entry-for($file).suite;
  }

  method register-group(:$description!, :&block!, :$file!, :$line!, :@tags = [], :$skipped, :$focused) {
    my IO::Path $path = ($file ~~ IO::Path ?? $file !! $file.IO).absolute.IO;
    my $entry = self.entry-for($path);
    $!current-entry = $entry;
    my $parent = $entry.stack.elems ?? $entry.stack[*-1] !! $entry.suite;
    my $group = example-group-type().new(:$description, :file($path), :$line);
    $group.set-metadata(:tags(@tags.list)) if @tags.elems;
    $group.set-metadata(:skipped(True))    if $skipped;
    $group.set-metadata(:focused(True))    if $focused;
    $parent.add-group($group);
    $entry.stack.push($group);
    LEAVE {
      $entry.stack.pop;
      $!current-entry = $entry.stack.elems ?? $entry !! Nil;
    }
    block();
    $group;
  }

  method register-example(:$description!, :&block!, :$file!, :$line!, :@tags = [], :$skipped, :$focused) {
    my IO::Path $path = ($file ~~ IO::Path ?? $file !! $file.IO).absolute.IO;
    my $entry = self.entry-for($path);
    my $parent = $entry.stack.elems ?? $entry.stack[*-1] !! $entry.suite;
    my $example = example-type().new(:$description, :file($path), :$line, :block(&block));

    my @lets;
    @lets.append: $entry.suite.let-definitions.list;
    for $entry.stack.grep(example-group-type()) -> $group {
      @lets.append: $group.let-definitions.list;
    }
    $example.set-metadata(:lets(@lets));
    $example.set-metadata(:tags(@tags.list)) if @tags.elems;
    $example.set-metadata(:skipped(True))    if $skipped;
    $example.set-metadata(:focused(True))    if $focused;
    $parent.add-example($example);
    $example;
  }

  method current-group-for(IO::Path $file) {
    my IO::Path $path = ($file ~~ IO::Path ?? $file !! $file.IO).absolute.IO;
    my $entry = self.entry-for($path);
    $entry.stack.elems ?? $entry.stack[*-1] !! Nil;
  }

  method suites() {
    %.entries.values.map(*.suite).List;
  }

  method suite-for-file(IO::Path $file) {
    my $key = $file.absolute.Str;
    %.entries{$key}:exists ?? %.entries{$key}.suite !! Nil;
  }

  method clear {
    %.entries = ();
  }
}

my SpecRegistry $REGISTRY .= new;

our sub registry() is export(:DEFAULT) {
  $REGISTRY;
}

our sub suites() is export(:DEFAULT) {
  $REGISTRY.suites;
}
