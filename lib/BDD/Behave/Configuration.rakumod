unit module BDD::Behave::Configuration;

our class ConfigInclude {
  has Mu  $.class is required;
  has Str $.as;
  has Str $.tag;
  has %.meta;

  method key(--> Str) {
    $!as.defined && $!as.chars ?? $!as !! $!class.^name.split('::')[*-1];
  }
}

our class ConfigHook {
  has Str      $.phase   is required;
  has Callable $.block   is required;
  has Str      $.tag;
  has Str      $.exclude-tag;
  has %.meta;

  method matches-example($example --> Bool) {
    return True unless $!tag.defined
                    || $!exclude-tag.defined
                    || %!meta.elems;
    my @tags = $example.effective-tags.list;
    if $!tag.defined {
      return False unless @tags.first(* eq $!tag).defined;
    }
    if $!exclude-tag.defined {
      return False if @tags.first(* eq $!exclude-tag).defined;
    }
    for %!meta.kv -> $k, $v {
      my $actual = $example.effective-metadata-value($k);
      return False unless $actual.defined;
      if $v ~~ Bool {
        return False unless ?$actual == $v;
      } else {
        return False unless $actual eq $v;
      }
    }
    True;
  }
}

our class Configuration {
  has Str      $.format               is rw;
  has Str      $.order                is rw;
  has Int      $.seed                 is rw;
  has Str      $.seed-mode            is rw;
  has Int      $.fail-fast            is rw;
  has Int      $.retry                is rw;
  has Bool     $.only-failures        is rw;
  has IO::Path $.failures-path        is rw;
  has Bool     $.verbose              is rw;
  has          $.aggregate-failures   is rw;
  has Int      $.profile-limit        is rw;
  has Real     $.slow-threshold       is rw;
  has Int      $.memory-profile-limit is rw;
  has Int      $.memory-threshold     is rw;
  has Bool     $.benchmark-mode       is rw;
  has Int      $.benchmark-iterations is rw;
  has IO::Path $.benchmark-baseline   is rw;
  has IO::Path $.benchmark-save       is rw;
  has Real     $.benchmark-threshold  is rw;
  has Str      $.benchmark-format     is rw;
  has IO::Path $.benchmark-output     is rw;
  has Bool     $.coverage             is rw;
  has Real     $.coverage-minimum     is rw;
  has Str      $.coverage-format      is rw;
  has IO::Path $.coverage-output      is rw;
  has IO::Path $.coverage-baseline    is rw;
  has Bool     $.coverage-branch      is rw;

  has Str @.include-tags;
  has Str @.exclude-tags;
  has Str @.example-patterns;
  has Str @.only-locations;
  has Str @.spec-paths;
  has Str @.coverage-include;
  has Str @.coverage-exclude;

  has ConfigInclude @.includes;
  has ConfigHook    @.hooks;
  has %.metadata-filters;
  has %.metadata-exclude-filters;
  has @.match-filters;

  method include-tag(*@tags) {
    @!include-tags.append: @tags.map(*.Str);
    self;
  }

  method exclude-tag(*@tags) {
    @!exclude-tags.append: @tags.map(*.Str);
    self;
  }

  method example-pattern(*@patterns) {
    @!example-patterns.append: @patterns.map(*.Str);
    self;
  }

  method only-location(*@locations) {
    @!only-locations.append: @locations.map(*.Str);
    self;
  }

  method include-spec(*@paths) {
    @!spec-paths.append: @paths.map(*.Str);
    self;
  }

  method coverage-include-path(*@paths) {
    @!coverage-include.append: @paths.map(*.Str);
    self;
  }

  method coverage-exclude-path(*@paths) {
    @!coverage-exclude.append: @paths.map(*.Str);
    self;
  }

  method include(Mu $class, Str :$as, Str :$tag, *%meta) {
    @!includes.push: ConfigInclude.new(:$class, :$as, :$tag, :%meta);
    self;
  }

  method before-all(&block, Str :$tag, Str :$exclude-tag, *%meta) {
    @!hooks.push: ConfigHook.new(
      :phase<before-all>, :&block, :$tag, :$exclude-tag, :%meta,
    );
    self;
  }

  method after-all(&block, Str :$tag, Str :$exclude-tag, *%meta) {
    @!hooks.push: ConfigHook.new(
      :phase<after-all>, :&block, :$tag, :$exclude-tag, :%meta,
    );
    self;
  }

  method before-each(&block, Str :$tag, Str :$exclude-tag, *%meta) {
    @!hooks.push: ConfigHook.new(
      :phase<before-each>, :&block, :$tag, :$exclude-tag, :%meta,
    );
    self;
  }

  method after-each(&block, Str :$tag, Str :$exclude-tag, *%meta) {
    @!hooks.push: ConfigHook.new(
      :phase<after-each>, :&block, :$tag, :$exclude-tag, :%meta,
    );
    self;
  }

  method around-each(&block, Str :$tag, Str :$exclude-tag, *%meta) {
    @!hooks.push: ConfigHook.new(
      :phase<around-each>, :&block, :$tag, :$exclude-tag, :%meta,
    );
    self;
  }

  method hooks-for(Str $phase --> List) {
    @!hooks.grep(*.phase eq $phase).List;
  }

  method filter(*%pairs) {
    for %pairs.kv -> $k, $v { %!metadata-filters{$k} = $v }
    self;
  }

  method exclude-filter(*%pairs) {
    for %pairs.kv -> $k, $v { %!metadata-exclude-filters{$k} = $v }
    self;
  }

  method filter-run-when-matching(*@keys, *%pairs) {
    for @keys -> $k { @!match-filters.push: $k.Str => True }
    for %pairs.kv -> $k, $v { @!match-filters.push: $k.Str => $v }
    self;
  }

  method merge(Configuration $other --> Configuration) {
    my $result = Configuration.new;
    for <format order seed seed-mode fail-fast retry only-failures failures-path verbose aggregate-failures
         profile-limit slow-threshold memory-profile-limit memory-threshold
         benchmark-mode benchmark-iterations benchmark-baseline benchmark-save
         benchmark-threshold benchmark-format benchmark-output
         coverage coverage-minimum coverage-format coverage-output
         coverage-baseline coverage-branch> -> $attr {
      my $self-val  = self."$attr"();
      my $other-val = $other."$attr"();
      my $picked = $other-val.defined ?? $other-val !! $self-val;
      $result."$attr"() = $picked if $picked.defined;
    }

    $result.include-tags.append:      |self.include-tags,      |$other.include-tags;
    $result.exclude-tags.append:      |self.exclude-tags,      |$other.exclude-tags;
    $result.example-patterns.append:  |self.example-patterns,  |$other.example-patterns;
    $result.only-locations.append:    |self.only-locations,    |$other.only-locations;
    $result.spec-paths.append:        |self.spec-paths,        |$other.spec-paths;
    $result.coverage-include.append:  |self.coverage-include,  |$other.coverage-include;
    $result.coverage-exclude.append:  |self.coverage-exclude,  |$other.coverage-exclude;
    $result.includes.append:          |self.includes,          |$other.includes;
    $result.hooks.append:             |self.hooks,             |$other.hooks;
    $result.match-filters.append:     |self.match-filters,     |$other.match-filters;

    for self.metadata-filters.kv -> $k, $v {
      $result.metadata-filters{$k} = $v;
    }
    for $other.metadata-filters.kv -> $k, $v {
      $result.metadata-filters{$k} = $v;
    }
    for self.metadata-exclude-filters.kv -> $k, $v {
      $result.metadata-exclude-filters{$k} = $v;
    }
    for $other.metadata-exclude-filters.kv -> $k, $v {
      $result.metadata-exclude-filters{$k} = $v;
    }

    $result;
  }

}

our sub defaults(--> Configuration) {
  my $c = Configuration.new;
  $c.format               = 'progress';
  $c.order                = 'random';
  $c.seed-mode            = 'xor';
  $c.fail-fast            = 0;
  $c.retry                = 0;
  $c.only-failures        = False;
  $c.verbose              = False;
  $c.aggregate-failures   = False;
  $c.profile-limit        = 0;
  $c.slow-threshold       = 0.Real;
  $c.memory-profile-limit = 0;
  $c.memory-threshold     = 0;
  $c.benchmark-mode       = False;
  $c.benchmark-iterations = 1;
  $c.benchmark-threshold  = 0.10;
  $c.benchmark-format     = 'text';
  $c.coverage             = False;
  $c.coverage-minimum     = 0.Real;
  $c.coverage-format      = 'html';
  $c.coverage-branch      = False;
  $c;
}

our sub user-config-path(--> IO::Path) {
  my $home = %*ENV<HOME> // '';
  return IO::Path unless $home.chars;
  $home.IO.add('.behave');
}

our sub project-config-path(IO::Path :$base = $*CWD --> IO::Path) {
  $base.IO.add('.behave');
}

our sub load-file(IO::Path $path --> Configuration) {
  my $config = Configuration.new;
  return $config unless $path.defined && $path.e;
  use MONKEY-SEE-NO-EVAL;
  {
    my $*BEHAVE-CONFIG = $config;
    try {
      EVALFILE $path;
      CATCH {
        default {
          die "Failed to load config file '{$path}': {.message}";
        }
      }
    }
  }
  $config;
}

our sub configure-behave(&block --> Nil) is export {
  my $config = $*BEHAVE-CONFIG;
  die "configure-behave called outside of a .behave config file"
    unless $config.defined;
  block($config);
}
