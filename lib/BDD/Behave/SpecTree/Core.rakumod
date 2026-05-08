unit module BDD::Behave::SpecTree::Core;

subset HookPhase of Str where { $_ eq any(<before-all after-all before-each after-each around-all around-each>) };

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

  method tags(--> List) {
    my $stored = %!metadata<tags>;
    return ().List unless $stored.defined;
    $stored ~~ Positional ?? $stored.list.List !! ($stored,).List;
  }

  method has-tag(Str:D $tag --> Bool) {
    self.tags.first(* eq $tag).defined;
  }

  method effective-tags(--> List) {
    my @collected;
    for self.ancestry -> $node {
      @collected.append: $node.tags;
    }
    @collected.unique.List;
  }

  method has-effective-tag(Str:D $tag --> Bool) {
    self.effective-tags.first(* eq $tag).defined;
  }

  method effective-metadata-value(Str:D $key) {
    for self.ancestry.reverse -> $node {
      my %meta := $node.metadata;
      next unless %meta{$key}:exists;
      my $value = %meta{$key};
      return $value if $value.defined;
    }
    Nil;
  }

  method skipped(--> Bool) { %!metadata<skipped> ?? True !! False }

  method focused(--> Bool) { %!metadata<focused> ?? True !! False }

  method effective-skipped(--> Bool) {
    self.ancestry.first(*.skipped).defined;
  }

  method effective-focused(--> Bool) {
    self.ancestry.first(*.focused).defined;
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

sub meta-value-matches($actual, $expected --> Bool) {
  return False unless $actual.defined;
  if $expected ~~ Positional {
    my @actual-list = $actual ~~ Positional ?? $actual.list !! ($actual,);
    for $expected.list -> $needle {
      return False unless @actual-list.first(* eq $needle).defined;
    }
    return True;
  }
  if $actual ~~ Positional {
    return $actual.list.first(* eq $expected).defined;
  }
  $actual eq $expected;
}

our class Hook {
  has Callable $.callback is required;
  has @.include-tags;
  has @.exclude-tags;
  has %.meta;

  method has-filter(--> Bool) {
    @!include-tags.elems > 0 || @!exclude-tags.elems > 0 || %!meta.elems > 0;
  }

  method matches(SpecNode:D $node --> Bool) {
    return True unless self.has-filter;

    my @effective-tags = $node.effective-tags;

    for @!include-tags -> $tag {
      return False unless @effective-tags.first(* eq $tag).defined;
    }

    for @!exclude-tags -> $tag {
      return False if @effective-tags.first(* eq $tag).defined;
    }

    for %!meta.kv -> $key, $expected {
      my $actual = $node.effective-metadata-value($key);
      return False unless meta-value-matches($actual, $expected);
    }

    True;
  }
}

sub base-exports() {
  %(
    HookPhase => HookPhase,
    SpecNode => SpecNode,
    Container => Container,
    Hook => Hook,
  );
}

sub EXPORT(:$ALL?) {
  my %exports = base-exports();
  %(
    DEFAULT => %exports,
    ALL => %exports,
  );
}
