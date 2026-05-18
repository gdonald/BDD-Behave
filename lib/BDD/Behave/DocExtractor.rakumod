unit module BDD::Behave::DocExtractor;

use BDD::Behave::Benchmark::Format;
use BDD::Behave::SpecTree;

constant Suite        = BDD::Behave::SpecTree::Suite;
constant ExampleGroup = BDD::Behave::SpecTree::ExampleGroup;
constant Example      = BDD::Behave::SpecTree::Example;

subset DocFormat of Str where { $_ eq any(<markdown html json>) };

sub html-escape(Str $s --> Str) {
  my $body = $s // '';
  $body = $body.subst('&', '&amp;',  :g);
  $body = $body.subst('<', '&lt;',   :g);
  $body = $body.subst('>', '&gt;',   :g);
  $body = $body.subst('"', '&quot;', :g);
  $body;
}

sub describe-status($example) {
  $example.pending  ?? 'pending'
                    !! ($example.effective-skipped ?? 'skipped'
                                                   !! ($example.effective-focused ?? 'focused'
                                                                                  !! 'passing'));
}

sub status-suffix(Str $status --> Str) {
  given $status {
    when 'pending' { ' (PENDING)' }
    when 'skipped' { ' (SKIPPED)' }
    when 'focused' { ' (FOCUSED)' }
    default        { '' }
  }
}

our class DocExtractor {
  has DocFormat $.format = 'markdown';
  has @.include-tags;
  has @.exclude-tags;
  has @.example-patterns;
  has %.metadata-filters;
  has %.metadata-exclude-filters;

  method has-filters(--> Bool) {
    so @!include-tags.elems
      || @!exclude-tags.elems
      || @!example-patterns.elems
      || %!metadata-filters.elems
      || %!metadata-exclude-filters.elems;
  }

  method example-matches(Example $example --> Bool) {
    my @tags = $example.effective-tags;

    if @!exclude-tags.elems
       && @tags.first({ $_ ∈ @!exclude-tags }).defined {
      return False;
    }

    if @!include-tags.elems
       && !@tags.first({ $_ ∈ @!include-tags }).defined {
      return False;
    }

    if @!example-patterns.elems {
      my $full = self.full-description($example);
      my $any = False;
      for @!example-patterns -> $pattern {
        if self.description-matches-pattern($full, $pattern) {
          $any = True;
          last;
        }
      }
      return False unless $any;
    }

    for %!metadata-filters.kv -> $key, $expected {
      return False unless self.metadata-matches($example, $key, $expected);
    }
    for %!metadata-exclude-filters.kv -> $key, $expected {
      return False if self.metadata-matches($example, $key, $expected);
    }

    True;
  }

  method metadata-matches(Example $example, Str $key, $expected --> Bool) {
    my $actual = $example.effective-metadata-value($key);
    return False unless $actual.defined;
    if $expected ~~ Bool {
      return $expected ?? ?$actual !! !$actual;
    }
    $actual eq $expected;
  }

  method description-matches-pattern(Str $description, Str $pattern --> Bool) {
    if $pattern.chars > 2
       && $pattern.starts-with('/')
       && $pattern.ends-with('/') {
      my $body = $pattern.substr(1, $pattern.chars - 2);
      my $rx = / <{ $body }> /;
      return so $description.match($rx);
    }
    $description.contains($pattern);
  }

  method full-description($example --> Str) {
    my @parts;
    for $example.ancestry -> $node {
      next if $node ~~ Suite;
      @parts.push: $node.description if $node.description.defined;
    }
    @parts.join(' ');
  }

  method group-has-matching-example(ExampleGroup $group --> Bool) {
    for $group.examples -> $ex {
      return True if self.example-matches($ex);
    }
    for $group.groups -> $g {
      return True if self.group-has-matching-example($g);
    }
    False;
  }

  method suite-has-matching-example(Suite $suite --> Bool) {
    for $suite.examples -> $ex {
      return True if self.example-matches($ex);
    }
    for $suite.groups -> $g {
      return True if self.group-has-matching-example($g);
    }
    False;
  }

  method extract(@suites --> Str) {
    given $!format {
      when 'markdown' { return self.render-markdown(@suites) }
      when 'html'     { return self.render-html(@suites)     }
      when 'json'     { return self.render-json(@suites)     }
    }
  }

  method render-markdown(@suites --> Str) {
    my @lines;
    my $multi = @suites.elems > 1;
    for @suites -> $suite {
      next if self.has-filters && !self.suite-has-matching-example($suite);
      if $multi {
        @lines.push: "# {$suite.description}";
        @lines.push: '';
      }
      self.md-render-children($suite, $multi ?? 2 !! 1, @lines);
    }
    @lines.join("\n") ~ "\n";
  }

  method md-render-children($container, Int $heading-level, @lines) {
    for $container.children -> $child {
      given $child {
        when ExampleGroup {
          next if self.has-filters && !self.group-has-matching-example($child);
          my $hashes = '#' x ($heading-level min 6);
          @lines.push: "$hashes {$child.description}";
          @lines.push: '';
          self.md-render-children($child, $heading-level + 1, @lines);
        }
        when Example {
          next if self.has-filters && !self.example-matches($child);
          my $status = describe-status($child);
          my $suffix = status-suffix($status);
          my $tags   = self.md-tag-suffix($child);
          @lines.push: "- {$child.description}{$suffix}{$tags}";
        }
      }
    }
    # blank line trailing examples so subsequent group heading separates cleanly
    if @lines.elems && @lines[*-1] ne '' {
      @lines.push: '';
    }
  }

  method md-tag-suffix($node --> Str) {
    my @tags = $node.tags;
    return '' unless @tags.elems;
    ' [' ~ @tags.join(', ') ~ ']';
  }

  method render-html(@suites --> Str) {
    my @lines;
    @lines.push: '<!DOCTYPE html>';
    @lines.push: '<html>';
    @lines.push: '<head><meta charset="utf-8"><title>Spec documentation</title></head>';
    @lines.push: '<body>';
    for @suites -> $suite {
      next if self.has-filters && !self.suite-has-matching-example($suite);
      @lines.push: '<section class="suite">';
      @lines.push: '<h1>' ~ html-escape($suite.description) ~ '</h1>';
      self.html-render-children($suite, 2, @lines);
      @lines.push: '</section>';
    }
    @lines.push: '</body>';
    @lines.push: '</html>';
    @lines.join("\n") ~ "\n";
  }

  method html-render-children($container, Int $heading-level, @lines) {
    my @child-examples;
    for $container.children -> $child {
      given $child {
        when ExampleGroup {
          next if self.has-filters && !self.group-has-matching-example($child);
          if @child-examples.elems {
            self.html-emit-example-list(@child-examples, @lines);
            @child-examples = [];
          }
          @lines.push: '<section class="group">';
          my $level = $heading-level min 6;
          @lines.push: "<h{$level}>" ~ html-escape($child.description) ~ "</h{$level}>";
          self.html-render-children($child, $heading-level + 1, @lines);
          @lines.push: '</section>';
        }
        when Example {
          next if self.has-filters && !self.example-matches($child);
          @child-examples.push: $child;
        }
      }
    }
    if @child-examples.elems {
      self.html-emit-example-list(@child-examples, @lines);
    }
  }

  method html-emit-example-list(@examples, @lines) {
    @lines.push: '<ul class="examples">';
    for @examples -> $ex {
      my $status = describe-status($ex);
      my $desc   = html-escape($ex.description);
      my $line   = '<li class="example status-' ~ $status ~ '">' ~ $desc;
      if $status ne 'passing' {
        $line ~= ' <em class="status">(' ~ $status ~ ')</em>';
      }
      my @tags = $ex.tags;
      if @tags.elems {
        $line ~= ' <span class="tags">[' ~ html-escape(@tags.join(', ')) ~ ']</span>';
      }
      $line ~= '</li>';
      @lines.push: $line;
    }
    @lines.push: '</ul>';
  }

  method render-json(@suites --> Str) {
    my @rendered-suites;
    for @suites -> $suite {
      next if self.has-filters && !self.suite-has-matching-example($suite);
      @rendered-suites.push: self.json-suite($suite);
    }
    BDD::Behave::Benchmark::Format::to-json(%(
      version => 1,
      suites  => @rendered-suites,
    ));
  }

  method json-suite(Suite $suite --> Hash) {
    %(
      description => $suite.description,
      file        => $suite.file.Str,
      groups      => self.json-groups($suite),
      examples    => self.json-examples($suite),
    );
  }

  method json-groups($container --> List) {
    my @groups;
    for $container.children -> $child {
      next unless $child ~~ ExampleGroup;
      next if self.has-filters && !self.group-has-matching-example($child);
      @groups.push: %(
        description => $child.description,
        file        => $child.file.Str,
        line        => $child.line,
        tags        => $child.tags.List,
        groups      => self.json-groups($child),
        examples    => self.json-examples($child),
      );
    }
    @groups.List;
  }

  method json-examples($container --> List) {
    my @examples;
    for $container.children -> $child {
      next unless $child ~~ Example;
      next if self.has-filters && !self.example-matches($child);
      @examples.push: %(
        description => $child.description,
        file        => $child.file.Str,
        line        => $child.line,
        tags        => $child.tags.List,
        pending     => $child.pending.so,
        skipped     => $child.effective-skipped.so,
        focused     => $child.effective-focused.so,
      );
    }
    @examples.List;
  }
}

sub base-exports() {
  %(
    DocExtractor => DocExtractor,
  );
}

sub EXPORT(:$ALL?) {
  my %exports = base-exports();
  %(
    DEFAULT => %exports,
    ALL => %exports,
  );
}
