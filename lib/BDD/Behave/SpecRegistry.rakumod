unit module BDD::Behave::SpecRegistry;

need BDD::Behave::SpecTree;

sub suite-type() { ::('BDD::Behave::SpecTree::Suite') }
sub example-group-type() { ::('BDD::Behave::SpecTree::ExampleGroup') }
sub example-type() { ::('BDD::Behave::SpecTree::Example') }

class Entry {
  has $.suite;
  has @.stack;
}

our class ExampleQueryResult {
  has Str      $.description         is required;
  has Str      $.full-description    is required;
  has IO::Path $.file                is required;
  has Int      $.line                is required;
  has IO::Path $.suite-file;
  has Str      $.suite-description;
  has Str      @.group-descriptions;
  has Str      @.tags;
  has %.metadata;
  has Bool     $.pending             = False;
  has Bool     $.focused             = False;
  has Bool     $.skipped             = False;

  method location(--> Str) { "{$!file}:{$!line}" }

  method to-hash(--> Hash) {
    %(
      description       => $!description,
      full-description  => $!full-description,
      file              => $!file.Str,
      line              => $!line,
      suite-file        => ($!suite-file.defined ?? $!suite-file.Str !! Str),
      suite-description => ($!suite-description // Str),
      group-descriptions => @!group-descriptions.List,
      tags              => @!tags.List,
      metadata          => %!metadata.Hash,
      pending           => $!pending,
      focused           => $!focused,
      skipped           => $!skipped,
    );
  }
}

sub matches-pattern(Str $description, Str $pattern --> Bool) {
  if $pattern.chars > 2
     && $pattern.starts-with('/')
     && $pattern.ends-with('/') {
    my $body = $pattern.substr(1, $pattern.chars - 2);
    my $rx = / <{ $body }> /;
    return so $description.match($rx);
  }
  $description.contains($pattern);
}

sub path-matches(IO::Path $node-path, Str $pattern-path --> Bool) {
  return True if $node-path.Str eq $pattern-path;
  return True if $node-path.absolute eq $pattern-path.IO.absolute;
  return True if $node-path.Str.ends-with('/' ~ $pattern-path);
  return True if $node-path.basename eq $pattern-path;
  False;
}

sub meta-value-equals($actual, $expected --> Bool) {
  return False unless $actual.defined;
  if $expected ~~ Bool {
    return $expected ?? ?$actual !! !$actual;
  }
  if $expected ~~ Positional {
    return False unless $actual ~~ Positional;
    my @a = $actual.list;
    my @e = $expected.list;
    return False unless @a.elems == @e.elems;
    for @e.kv -> $i, $v {
      return False unless @a[$i] eq $v;
    }
    return True;
  }
  if $actual ~~ Positional {
    return $actual.list.first(* eq $expected).defined;
  }
  $actual eq $expected;
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

  method register-group(:$description!, :&block!, :$file!, :$line!, :@tags = [], :%extra-meta = %(), :$skipped, :$focused) {
    my IO::Path $path = ($file ~~ IO::Path ?? $file !! $file.IO).absolute.IO;
    my $entry = self.entry-for($path);
    $!current-entry = $entry;
    my $parent = $entry.stack.elems ?? $entry.stack[*-1] !! $entry.suite;
    my $group = example-group-type().new(:$description, :file($path), :$line);
    $group.set-metadata(:tags(@tags.list)) if @tags.elems;
    $group.set-metadata(:skipped(True))    if $skipped;
    $group.set-metadata(:focused(True))    if $focused;
    for %extra-meta.kv -> $key, $value {
      $group.set-metadata(|%($key => $value));
    }
    $parent.add-group($group);
    $entry.stack.push($group);
    LEAVE {
      $entry.stack.pop;
      $!current-entry = $entry.stack.elems ?? $entry !! Nil;
    }
    block();
    $group;
  }

  method register-example(:$description!, :&block!, :$file!, :$line!, :@tags = [], :%extra-meta = %(), :$skipped, :$focused) {
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
    for %extra-meta.kv -> $key, $value {
      $example.set-metadata(|%($key => $value));
    }
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

  method all-examples(--> List) {
    my @results;
    for self.suites.list -> $suite {
      self!collect-examples($suite, $suite, [], @results);
    }
    @results.List;
  }

  method !collect-examples($node, $suite, @group-descriptions, @results) {
    given $node {
      when example-type() {
        @results.push: self!to-query-result($node, $suite, @group-descriptions);
      }
      when example-group-type() {
        my @next-groups = (|@group-descriptions, $node.description);
        for $node.children.list -> $child {
          self!collect-examples($child, $suite, @next-groups, @results);
        }
      }
      when suite-type() {
        for $node.children.list -> $child {
          self!collect-examples($child, $suite, @group-descriptions, @results);
        }
      }
    }
  }

  method !to-query-result($example, $suite, @group-descriptions --> ExampleQueryResult) {
    my %metadata = $example.metadata.clone;
    %metadata<lets>:delete;
    my $full-description = (|@group-descriptions, $example.description).join(' ');

    ExampleQueryResult.new(
      description       => $example.description,
      :$full-description,
      file              => $example.file,
      line              => $example.line,
      suite-file        => $suite.file,
      suite-description => $suite.description,
      group-descriptions => @group-descriptions.List,
      tags              => $example.effective-tags.List,
      :%metadata,
      pending           => $example.pending.so,
      focused           => $example.effective-focused.so,
      skipped           => $example.effective-skipped.so,
    );
  }

  method query-examples(
    :$description-pattern,
    :$file,
    :$line,
    :@include-tags    = [],
    :@exclude-tags    = [],
    :%metadata        = %(),
    :%metadata-exclude = %(),
    :$pending,
    :$focused,
    :$skipped,
    --> List
  ) {
    my @all = self.all-examples;
    my @kept;
    for @all -> $r {
      if $description-pattern.defined && $description-pattern.chars {
        next unless matches-pattern($r.full-description, $description-pattern);
      }

      if $file.defined {
        my $pattern-path = $file ~~ IO::Path ?? $file.Str !! $file.Str;
        next unless path-matches($r.file, $pattern-path);
      }

      if $line.defined {
        next unless $r.line == $line;
      }

      if @include-tags.elems {
        next unless @include-tags.first({ $r.tags.first(* eq $_).defined }).defined;
      }

      if @exclude-tags.elems {
        next if @exclude-tags.first({ $r.tags.first(* eq $_).defined }).defined;
      }

      my $matches-meta = True;
      for %metadata.kv -> $k, $v {
        unless meta-value-equals($r.metadata{$k}, $v) {
          $matches-meta = False;
          last;
        }
      }
      next unless $matches-meta;

      my $excluded = False;
      for %metadata-exclude.kv -> $k, $v {
        if meta-value-equals($r.metadata{$k}, $v) {
          $excluded = True;
          last;
        }
      }
      next if $excluded;

      if $pending.defined {
        next unless ?$r.pending == ?$pending;
      }

      if $focused.defined {
        next unless ?$r.focused == ?$focused;
      }

      if $skipped.defined {
        next unless ?$r.skipped == ?$skipped;
      }

      @kept.push: $r;
    }
    @kept.List;
  }

  method count-examples(|args --> Int) {
    self.query-examples(|args).elems;
  }
}

my SpecRegistry $REGISTRY .= new;

our sub registry() is export(:DEFAULT) {
  $REGISTRY;
}

our sub suites() is export(:DEFAULT) {
  $REGISTRY.suites;
}
