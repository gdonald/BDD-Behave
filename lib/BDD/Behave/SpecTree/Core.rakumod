unit module BDD::Behave::SpecTree::Core;

subset HookPhase of Str where { $_ eq any(<before-all after-all before-each after-each>) };

our class SpecNode {
  has Str $.description is required;
  has IO::Path $.file is required;
  has Int $.line is required;
  has $.parent is rw = Nil;
  has %.metadata = Hash.new;

  submethod BUILD(:$!description, :$file!, :$line!, :$parent, :%metadata = {}) {
    $!file = $file ~~ IO::Path ?? $file !! $file.IO;
    $!line = $line;
    $!parent = $parent if $parent.defined;
    %!metadata = %metadata.clone;
  }

  method location { "$!file:$!line" }

  method root { self.ancestry[0] }

  method ancestry {
    gather {
      my $node = self;
      while $node.defined {
        take $node;
        $node = $node.parent;
      }
    }.reverse.List;
  }

  method set-metadata(*%pairs) {
    for %pairs.kv -> $key, $value {
      %!metadata{$key} = $value;
    }
    self;
  }

  method get-metadata(Str:D $key, :$default) {
    %!metadata{$key} // $default;
  }

  method depth { self.ancestry.elems - 1 }

  method is-root { !self.parent.defined }
}

our role Container {
  has SpecNode @.children;

  method add-child(SpecNode $child --> SpecNode) {
    $child.parent = self;
    @!children.push($child);
    $child;
  }
}

sub base-exports() {
  %(
    HookPhase => HookPhase,
    SpecNode => SpecNode,
    Container => Container,
  );
}

sub EXPORT(:$ALL?) {
  my %exports = base-exports();
  %(
    DEFAULT => %exports,
    ALL => %exports,
  );
}
