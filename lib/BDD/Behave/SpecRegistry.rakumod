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

  method register-group(:$description!, :&block!, :$file!, :$line!) {
    my IO::Path $path = ($file ~~ IO::Path ?? $file !! $file.IO).absolute.IO;
    my $entry = self.entry-for($path);
    my $parent = $entry.stack.elems ?? $entry.stack[*-1] !! $entry.suite;
    my $group = example-group-type().new(:$description, :file($path), :$line);
    $parent.add-group($group);
    $entry.stack.push($group);
    LEAVE $entry.stack.pop;
    block();
    $group;
  }

  method register-example(:$description!, :&block!, :$file!, :$line!) {
    my IO::Path $path = ($file ~~ IO::Path ?? $file !! $file.IO).absolute.IO;
    my $entry = self.entry-for($path);
    my $parent = $entry.stack.elems ?? $entry.stack[*-1] !! $entry.suite;
    my $example = example-type().new(:$description, :file($path), :$line, :block(&block));
    $parent.add-example($example);
    $example;
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
