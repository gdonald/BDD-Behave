unit module BDD::Behave::DryRun;

use BDD::Behave::Benchmark::Format;
use BDD::Behave::SpecTree;

constant Suite = BDD::Behave::SpecTree::Suite;
constant ExampleGroup = BDD::Behave::SpecTree::ExampleGroup;
constant Example = BDD::Behave::SpecTree::Example;

sub example-matches(
  Example $ex,
  @include-tags, @exclude-tags, @example-patterns, @only-locations,
  Bool :$focus-mode,
  --> Bool
) {
  my @tags = $ex.effective-tags;

  if @exclude-tags.elems
     && @tags.first({ $_ ∈ @exclude-tags }).defined {
    return False;
  }

  if $focus-mode
     && !$ex.effective-focused
     && !$ex.effective-skipped {
    return False;
  }

  if @include-tags.elems
     && !@tags.first({ $_ ∈ @include-tags }).defined {
    return False;
  }

  if @example-patterns.elems {
    my $description = full-description($ex);
    my $matched = False;
    for @example-patterns -> $pattern {
      if matches-pattern($description, $pattern) {
        $matched = True;
        last;
      }
    }
    return False unless $matched;
  }

  if @only-locations.elems {
    my $matched = False;
    for @only-locations -> $loc {
      if location-matches-node($ex, $loc) {
        $matched = True;
        last;
      }
      for $ex.ancestry -> $node {
        next unless $node ~~ ExampleGroup;
        if location-matches-node($node, $loc) {
          $matched = True;
          last;
        }
      }
      last if $matched;
    }
    return False unless $matched;
  }

  True;
}

sub full-description(Example $ex --> Str) {
  my @parts = $ex.ancestry.grep(ExampleGroup).map(*.description);
  @parts.push: $ex.description;
  @parts.join(' ');
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

sub location-matches-node($node, Str $loc --> Bool) {
  return False unless $loc.contains(':');
  my $idx = $loc.rindex(':');
  my $pattern-path = $loc.substr(0, $idx);
  my $pattern-line = $loc.substr($idx + 1);
  return False unless $node.line.Str eq $pattern-line;
  path-matches($node.file.Str, $pattern-path);
}

sub path-matches(Str $node-path, Str $pattern-path --> Bool) {
  return True if $node-path eq $pattern-path;
  return True if $node-path.IO.absolute eq $pattern-path.IO.absolute;
  return True if $node-path.ends-with('/' ~ $pattern-path);
  return True if $node-path.IO.basename eq $pattern-path;
  False;
}

sub has-focus(@suites --> Bool) {
  for @suites -> $s {
    return True if has-focus-node($s);
  }
  False;
}

sub has-focus-node($node --> Bool) {
  given $node {
    when Example {
      return True if $node.focused;
    }
    default {
      return True if $node.focused;
      for $node.children.list -> $child {
        return True if has-focus-node($child);
      }
    }
  }
  False;
}

our class FilterOptions {
  has @.include-tags;
  has @.exclude-tags;
  has @.example-patterns;
  has @.only-locations;
}

our sub matching-examples(@suites, FilterOptions $opts --> List) {
  my $focus-mode = has-focus(@suites);
  my @results;
  for @suites -> $suite {
    walk-collect($suite, $opts, $focus-mode, @results);
  }
  @results.List;
}

sub walk-collect($node, $opts, $focus-mode, @out) {
  given $node {
    when Example {
      if example-matches(
        $node,
        $opts.include-tags, $opts.exclude-tags,
        $opts.example-patterns, $opts.only-locations,
        :$focus-mode,
      ) {
        @out.push: $node;
      }
    }
    default {
      for $node.children.list -> $child {
        walk-collect($child, $opts, $focus-mode, @out);
      }
    }
  }
}

sub status-label(Example $ex --> Str) {
  return 'pending' if $ex.pending;
  return 'skipped' if $ex.effective-skipped;
  return 'focused' if $ex.effective-focused;
  '';
}

our sub render-text(@suites, FilterOptions $opts, Bool :$verbose = False --> Str) {
  my $focus-mode = has-focus(@suites);
  my @lines;
  my $multi = @suites.elems > 1;
  for @suites -> $suite {
    next unless suite-has-match($suite, $opts, $focus-mode);
    if $multi {
      @lines.push: "# {$suite.description}";
      @lines.push: '';
    }
    render-text-children(
      $suite, $opts, $focus-mode, $multi ?? 1 !! 0, @lines, :$verbose,
    );
    @lines.push: '' if @lines.elems && @lines[*-1] ne '';
  }
  my $count = matching-examples(@suites, $opts).elems;
  @lines.push: "$count {$count == 1 ?? 'example' !! 'examples'}";
  @lines.join("\n") ~ "\n";
}

sub suite-has-match($container, FilterOptions $opts, Bool $focus-mode --> Bool) {
  for $container.children.list -> $child {
    given $child {
      when Example {
        return True if example-matches(
          $child,
          $opts.include-tags, $opts.exclude-tags,
          $opts.example-patterns, $opts.only-locations,
          :$focus-mode,
        );
      }
      default {
        return True if suite-has-match($child, $opts, $focus-mode);
      }
    }
  }
  False;
}

sub render-text-children(
  $container, $opts, $focus-mode, Int $depth, @lines, Bool :$verbose,
) {
  for $container.children.list -> $child {
    given $child {
      when ExampleGroup {
        next unless suite-has-match($child, $opts, $focus-mode);
        @lines.push: ('  ' x $depth) ~ $child.description;
        render-text-children(
          $child, $opts, $focus-mode, $depth + 1, @lines, :$verbose,
        );
      }
      when Example {
        next unless example-matches(
          $child,
          $opts.include-tags, $opts.exclude-tags,
          $opts.example-patterns, $opts.only-locations,
          :$focus-mode,
        );
        my $status = status-label($child);
        my $suffix = $status.chars ?? " ({$status.uc})" !! '';
        @lines.push: ('  ' x $depth) ~ $child.description ~ $suffix;
        if $verbose {
          my $indent = '  ' x ($depth + 1);
          @lines.push: $indent ~ $child.file ~ ':' ~ $child.line;
          my @tags = $child.effective-tags;
          @lines.push: $indent ~ 'tags: ' ~ @tags.join(', ') if @tags.elems;
        }
      }
    }
  }
}

our sub render-json(@suites, FilterOptions $opts, :@load-errors --> Str) {
  my $focus-mode = has-focus(@suites);
  my @examples;
  for matching-examples(@suites, $opts) -> $ex {
    my %m = $ex.metadata.clone;
    %m<lets>:delete;
    @examples.push: %(
      description       => $ex.description,
      full-description  => full-description($ex),
      file              => $ex.file.Str,
      line              => $ex.line,
      tags              => $ex.effective-tags.List,
      metadata          => %m,
      pending           => $ex.pending.so,
      focused           => $ex.effective-focused.so,
      skipped           => $ex.effective-skipped.so,
    );
  }

  my @suite-tree = @suites.map(&serialize-suite-node);

  my @load-error-records = @load-errors.map(-> %e {
    %(
      file    => (%e<file> // '').Str,
      message => (%e<message> // '').Str,
    );
  });

  BDD::Behave::Benchmark::Format::to-json(%(
    version      => 1,
    count        => @examples.elems,
    examples     => @examples,
    suites       => @suite-tree,
    'load-errors' => @load-error-records,
  ));
}

our sub serialize-suite-node($node --> Hash) {
  given $node {
    when Suite {
      %(
        type        => 'suite',
        description => $node.description,
        file        => $node.file.Str,
        line        => $node.line,
        metadata    => sanitize-metadata($node.metadata),
        children    => $node.children.map(&serialize-suite-node).List,
      );
    }
    when ExampleGroup {
      %(
        type        => 'group',
        description => $node.description,
        file        => $node.file.Str,
        line        => $node.line,
        metadata    => sanitize-metadata($node.metadata),
        children    => $node.children.map(&serialize-suite-node).List,
      );
    }
    when Example {
      %(
        type        => 'example',
        description => $node.description,
        file        => $node.file.Str,
        line        => $node.line,
        metadata    => sanitize-metadata($node.metadata),
        pending     => $node.pending.so,
      );
    }
    default {
      %();
    }
  }
}

sub sanitize-metadata(%metadata --> Hash) {
  my %m = %metadata.clone;
  %m<lets>:delete;
  %m;
}
