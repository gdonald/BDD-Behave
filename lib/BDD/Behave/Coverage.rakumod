unit module BDD::Behave::Coverage;

use BDD::Behave::Colors;

our class CoverageOptions {
  has Bool     $.enabled            is rw = False;
  has Real     $.minimum            is rw = 0.Real;
  has Str      @.include-paths      is rw;
  has Str      @.exclude-paths      is rw;
  has Str      $.format             is rw = 'text';
  has IO::Path $.output             is rw;
  has IO::Path $.baseline           is rw;
  has Bool     $.branch             is rw = False;

  method include-path(*@paths) {
    @!include-paths.append: @paths.map(*.Str);
    self;
  }

  method exclude-path(*@paths) {
    @!exclude-paths.append: @paths.map(*.Str);
    self;
  }
}

our class FileCoverage {
  has Str  $.path is required;
  has Str  $.display-path is rw;
  has SetHash $.hits            = SetHash.new;
  has SetHash $.executable      = SetHash.new;
  has SetHash $.branch-lines    = SetHash.new;
  has SetHash $.branches-hit    = SetHash.new;

  method add-hit(Int $line) {
    $!hits{$line} = True;
  }

  method total-lines(--> Int) {
    $!executable.elems;
  }

  method covered-lines(--> Int) {
    ($!hits (&) $!executable).elems;
  }

  method missing-lines(--> List) {
    ($!executable (-) $!hits).keys.map(*.Int).sort.List;
  }

  method covered-line-numbers(--> List) {
    ($!hits (&) $!executable).keys.map(*.Int).sort.List;
  }

  method percentage(--> Real) {
    my $total = self.total-lines;
    return 100e0 if $total == 0;
    (self.covered-lines * 100 / $total).Real;
  }

  method total-branches(--> Int) {
    $!branch-lines.elems;
  }

  method covered-branches(--> Int) {
    ($!branches-hit (&) $!branch-lines).elems;
  }

  method branch-percentage(--> Real) {
    my $total = self.total-branches;
    return 100e0 if $total == 0;
    (self.covered-branches * 100 / $total).Real;
  }
}

our class CoverageReport {
  has FileCoverage @.files is rw;
  has IO::Path     $.root  is rw;
  has Bool         $.branch is rw = False;

  method total-lines(--> Int) {
    [+] @!files.map(*.total-lines);
  }

  method covered-lines(--> Int) {
    [+] @!files.map(*.covered-lines);
  }

  method overall-percentage(--> Real) {
    my $t = self.total-lines;
    return 100e0 if $t == 0;
    (self.covered-lines * 100 / $t).Real;
  }

  method total-branches(--> Int) {
    [+] @!files.map(*.total-branches);
  }

  method covered-branches(--> Int) {
    [+] @!files.map(*.covered-branches);
  }

  method overall-branch-percentage(--> Real) {
    my $t = self.total-branches;
    return 100e0 if $t == 0;
    (self.covered-branches * 100 / $t).Real;
  }
}

our sub identify-executable-lines(IO::Path $file --> SetHash) {
  my $set = SetHash.new;
  return $set unless $file.e;
  my @lines = $file.lines;
  my @continuations = compute-continuation-lines($file);
  my $in-pod = False;
  my $prev-ended-cleanly = True;

  for @lines.kv -> $idx, $line {
    my $lineno = $idx + 1;
    my $trimmed = $line.trim;

    if $trimmed.starts-with('=begin pod') || $trimmed.starts-with('=pod') {
      $in-pod = True;
      next;
    }
    if $trimmed.starts-with('=end pod') {
      $in-pod = False;
      next;
    }
    next if $in-pod;

    if $trimmed eq '' || $trimmed.starts-with('#') {
      next;
    }

    # Update prev-ended-cleanly for the NEXT iteration based on what
    # this line's actual code (minus trailing comments) ends with.
    # `;` and `{` are unambiguous statement terminators. `}` is a clean
    # close only when it is itself the last token (i.e. preceded by
    # whitespace or alone on the line); a `}` glued to content is a
    # hash/array subscript close inside a multi-line expression.
    my sub update-state() {
      my $cleaned = strip-trailing-comment($line).trim-trailing;
      return if $cleaned eq '';
      my $last = $cleaned.substr(*-1);
      if $last eq ';' || $last eq '{' {
        $prev-ended-cleanly = True;
      } elsif $last eq '}' {
        if $cleaned.chars < 2 {
          $prev-ended-cleanly = True;
        } else {
          my $prev = $cleaned.substr(*-2, 1);
          $prev-ended-cleanly = ($prev eq ' ' || $prev eq "\t" || $prev eq '}');
        }
      } else {
        $prev-ended-cleanly = False;
      }
    }

    if $trimmed eq 'else' | 'else {' | '} else {' | '}else{' {
      update-state();
      next;
    }
    if is-closing-continuation($trimmed)
    || is-bare-value-line($trimmed)
    || is-declarative-line($trimmed)
    || is-multiline-routine-header($trimmed)
    || (($idx < @continuations.elems) && @continuations[$idx])
    || !$prev-ended-cleanly {
      update-state();
      next;
    }

    $set{$lineno} = True;
    update-state();
  }
  $set;
}

our sub strip-trailing-comment(Str $line --> Str) {
  my $state = 'normal';
  my $i = 0;
  my $len = $line.chars;
  while $i < $len {
    my $c = $line.substr($i, 1);
    given $state {
      when 'normal' {
        if    $c eq '#'  { return $line.substr(0, $i) }
        elsif $c eq '"'  { $state = 'dstr' }
        elsif $c eq "'"  { $state = 'sstr' }
      }
      when 'dstr' {
        if    $c eq '\\' { $i++ }
        elsif $c eq '"'  { $state = 'normal' }
      }
      when 'sstr' {
        if    $c eq '\\' { $i++ }
        elsif $c eq "'"  { $state = 'normal' }
      }
    }
    $i++;
  }
  $line;
}

# Returns an array whose i-th element is True iff line (i + 1) starts with
# the innermost open bracket being a ( or [, meaning the line is a
# continuation of a multi-line paren/bracket expression that MoarVM
# attributes to its starting line. Once a { opens (e.g. a lambda body
# passed to .map(...)), the new top is { and inner lines are NOT
# continuations — they are real statements MoarVM emits HITs for.
our sub compute-continuation-lines(IO::Path $file --> Array) {
  my @result;
  return @result unless $file.e;
  my $content = $file.slurp;
  my @stack;
  my $state = 'normal';  # normal | sstr | dstr | line-comment
  @result.push: False;   # line 1 is never a continuation
  my $i = 0;
  my $len = $content.chars;
  while $i < $len {
    my $c = $content.substr($i, 1);
    given $state {
      when 'normal' {
        if    $c eq '#' { $state = 'line-comment' }
        elsif $c eq '"' { $state = 'dstr' }
        elsif $c eq "'" { $state = 'sstr' }
        elsif $c eq '(' { @stack.push: '(' }
        elsif $c eq '[' { @stack.push: '[' }
        elsif $c eq '{' { @stack.push: '{' }
        elsif $c eq ')' | ']' | '}' { @stack.pop if @stack.elems }
      }
      when 'dstr' {
        if    $c eq '\\' { $i++ }
        elsif $c eq '"'  { $state = 'normal' }
      }
      when 'sstr' {
        if    $c eq '\\' { $i++ }
        elsif $c eq "'"  { $state = 'normal' }
      }
      when 'line-comment' {
        $state = 'normal' if $c eq "\n";
      }
    }
    if $c eq "\n" {
      my $top = @stack.elems ?? @stack[*-1] !! '';
      @result.push: ($top eq '(' || $top eq '[');
    }
    $i++;
  }
  @result;
}

our sub is-closing-continuation(Str $trimmed --> Bool) {
  return False unless $trimmed.chars;
  my $first = $trimmed.substr(0, 1);
  return False unless $first eq '}' | ')' | ']';
  # `} else {` and friends open a new block; let them through so the
  # existing else-handling skip rules apply.
  return False if $trimmed.ends-with('{');
  True;
}

our sub is-bare-value-line(Str $trimmed --> Bool) {
  # A single identifier, optionally with sigil and twigil, optionally
  # followed by `;`. Examples: `%rec`, `$result;`, `@list;`, `result`.
  # Literals like `True;`, `42;`, `'foo';` also count.
  return True if $trimmed ~~
  / ^ <[@%$&]>? <[!^.?=~:*]>? \w [ \w | '-' ]* ';'? $ /;
  return True if $trimmed ~~ / ^ \d+ ';'? $ /;
  False;
}

our sub is-multiline-routine-header(Str $trimmed --> Bool) {
  # `multi method foo(...` style line whose signature continues to the
  # next line (no `{` on this line). Marking as non-executable avoids
  # the source-rewriter putting code before a method/sub declarator,
  # which Raku doesn't accept in class scope.
  return False if $trimmed.contains('{');
  return True if $trimmed ~~
  / ^ [ 'multi' \s+ | 'proto' \s+ | 'only' \s+ ]?
  [ 'sub' | 'method' | 'submethod' ]
  \s+ \S /;
  False;
}

our sub is-declarative-line(Str $trimmed --> Bool) {
  return True if $trimmed.starts-with('use ')
  || $trimmed.starts-with('need ')
  || $trimmed.starts-with('require ')
  || $trimmed.starts-with('import ');
  return True if $trimmed.starts-with('unit ');
  return True if $trimmed.starts-with('has ')
  || $trimmed.starts-with('has(');
  return True if $trimmed.starts-with('constant ');
  return True if $trimmed.starts-with('subset ');
  return True if $trimmed.starts-with('enum ');

  # `class Foo`, `role Foo`, `grammar Foo`, optionally with `my` or `our`,
  # and any trailing trait / signature.
  return True if $trimmed ~~
  / ^ [ 'my' \s+ | 'our' \s+ ]?
  [ 'class' | 'role' | 'grammar' ]
  \s+ \S /;

  # Pure `my` / `our` / `state` declarations with no initializer compile to
  # zero runtime bytecode (just a lexical slot), so MoarVM never emits a
  # HIT for the line. Heuristic: the line starts with one of those keywords
  # AND, after stripping `=>` and `==`, contains no `=` (no assignment,
  # no `:=` bind, no `.=` mutator).
  if $trimmed.starts-with('my ' | 'our ' | 'state ') {
    my $stripped = $trimmed.subst('=>', '', :g).subst('==', '', :g);
    return True unless $stripped.contains('=');
  }

  False;
}

our sub identify-branch-lines(IO::Path $file --> SetHash) {
  my $set = SetHash.new;
  return $set unless $file.e;
  my @lines = $file.lines;
  my $rx = / ^ \h* [
    'if' | 'elsif' | 'unless' | 'with' | 'without'
    | 'when' | 'while' | 'until' | 'given' | 'for'
  ] [ \h | '(' ] /;
  my $rx-postfix = / \h [
    'if' | 'unless' | 'with' | 'without' | 'while' | 'until'
  ] \h \S /;
  my $in-pod = False;
  for @lines.kv -> $idx, $line {
    my $lineno = $idx + 1;
    my $trimmed = $line.trim;
    if $trimmed.starts-with('=begin pod') || $trimmed.starts-with('=pod') {
      $in-pod = True;
      next;
    }
    if $trimmed.starts-with('=end pod') {
      $in-pod = False;
      next;
    }
    next if $in-pod;
    next if $trimmed eq '';
    next if $trimmed.starts-with('#');
    if $line ~~ $rx || $line ~~ $rx-postfix {
      $set{$lineno} = True;
    }
  }
  $set;
}

our sub matches-path-filter(Str $file, @include, @exclude --> Bool) {
  if @exclude {
    for @exclude -> $pat {
      return False if $file.contains($pat);
    }
  }
  if @include {
    my $any = False;
    for @include -> $pat {
      if $file.starts-with($pat) {
        $any = True;
        last;
      }
    }
    return False unless $any;
  }
  True;
}

our sub process-hit-line(
  Str $line,
  %hits,
  :@include-paths,
  :@exclude-paths,
) {
  return Nil unless $line.starts-with('HIT');

  my $rest = $line.substr(4).trim-leading;
  my $last-space = $rest.rindex(' ');
  return Nil unless $last-space.defined;

  my $line-token = $rest.substr($last-space + 1);
  return Nil unless $line-token ~~ /^ \d+ $/;
  my $line-num = $line-token.Int;

  my $file-part = $rest.substr(0, $last-space).trim;

  if $file-part ~~ / (.+) ' (' <-[)]>+ ')' $/ {
    $file-part = ~$0;
  }

  return Nil unless matches-path-filter($file-part, @include-paths, @exclude-paths);

  %hits{$file-part} //= SetHash.new;
  %hits{$file-part}{$line-num} = True;
  Nil;
}

our sub parse-coverage-log(
  IO::Path $log-path,
  :@include-paths,
  :@exclude-paths,
  --> Hash
) {
  my %hits;
  return %hits unless $log-path.defined && $log-path.e;
  for $log-path.lines -> $line {
    process-hit-line($line, %hits, :@include-paths, :@exclude-paths);
  }
  %hits;
}

our sub parse-coverage-stream(
  IO::Handle $fh,
  :@include-paths,
  :@exclude-paths,
  --> Hash
) {
  my %hits;
  for $fh.lines -> $line {
    process-hit-line($line, %hits, :@include-paths, :@exclude-paths);
  }
  %hits;
}

our sub merge-coverage-logs(
  @log-paths,
  :@include-paths,
  :@exclude-paths,
  --> Hash
) {
  my %hits;
  for @log-paths -> $p {
    my $io = $p ~~ IO::Path ?? $p !! $p.IO;
    next unless $io.defined && $io.e;
    for $io.lines -> $line {
      process-hit-line($line, %hits, :@include-paths, :@exclude-paths);
    }
  }
  %hits;
}

our sub normalize-display-path(Str $file, IO::Path $root --> Str) {
  my $abs = $file.IO.absolute;
  my $root-abs = $root.absolute ~ '/';
  return $abs.substr($root-abs.chars) if $abs.starts-with($root-abs);
  $file;
}

our sub build-report-from-hits(
  %hits,
  CoverageOptions $opts,
  IO::Path        $root,
  --> CoverageReport
) {
  my %by-abs;
  for %hits.keys -> $path {
    my $io = $path.IO;
    next unless $io.e;
    my $abs = $io.absolute;
    %by-abs{$abs} //= FileCoverage.new(:path($abs));
    my $fc = %by-abs{$abs};
    $fc.display-path = normalize-display-path($abs, $root);
    $fc.executable = identify-executable-lines($io) unless $fc.executable.elems;
    if $opts.branch && !$fc.branch-lines.elems {
      $fc.branch-lines = identify-branch-lines($io);
    }
    for %hits{$path}.keys -> $ln {
      $fc.add-hit($ln.Int);
      $fc.branches-hit{$ln.Int} = True if $opts.branch;
    }
  }

  my @candidate-files = enumerate-include-files(
    $opts.include-paths, $opts.exclude-paths, $root,
  );
  for @candidate-files -> $io {
    my $abs = $io.absolute;
    next if %by-abs{$abs}:exists;
    my $fc = FileCoverage.new(:path($abs));
    $fc.display-path = normalize-display-path($abs, $root);
    $fc.executable   = identify-executable-lines($io);
    if $opts.branch {
      $fc.branch-lines = identify-branch-lines($io);
    }
    %by-abs{$abs} = $fc;
  }

  my @files = %by-abs.values.sort(*.display-path).List;
  CoverageReport.new(:@files, :$root, :branch($opts.branch));
}

our sub build-report(
  IO::Path        $log-path,
  CoverageOptions $opts,
  IO::Path        $root,
  --> CoverageReport
) {
  my %hits = parse-coverage-log(
    $log-path,
    :include-paths(@($opts.include-paths)),
    :exclude-paths(@($opts.exclude-paths)),
  );
  build-report-from-hits(%hits, $opts, $root);
}

our sub enumerate-include-files(@include, @exclude, IO::Path $root --> List) {
  my @result;
  my @roots = @include.elems ?? @include !! ('lib',);
  for @roots -> $r {
    my $io = $r.IO.is-absolute ?? $r.IO !! $root.add($r);
    next unless $io.e;
    if $io.f {
      next unless $io.basename ~~ / '.' (rakumod | raku | pm6) $/;
      next if @exclude.first({ $io.absolute.contains($_) });
      @result.push: $io;
    } elsif $io.d {
      for find-source-files($io) -> $f {
        next if @exclude.first({ $f.absolute.contains($_) });
        @result.push: $f;
      }
    }
  }
  @result.List;
}

our sub find-source-files(IO::Path $dir --> List) {
  my @out;
  return @out.List unless $dir.e && $dir.d;
  for $dir.dir -> $entry {
    if $entry.d {
      @out.append: find-source-files($entry);
    } elsif $entry.f {
      @out.push: $entry if $entry.basename ~~ / '.' (rakumod | raku | pm6) $/;
    }
  }
  @out.List;
}

# Renderers

our sub render-text(CoverageReport $report, Bool :$color = True --> Str) {
  my @lines;
  @lines.push: 'Coverage report';
  @lines.push: '===============';

  my $name-width = max(20, |($report.files.map(*.display-path.chars)));
  my $header = sprintf '%-*s  %8s  %5s',
  $name-width, 'File', 'Lines', 'Cov%';
  @lines.push: $header;
  @lines.push: '-' x $header.chars;

  for $report.files -> $f {
    my $pct = sprintf '%5.1f', $f.percentage;
    my $row = sprintf '%-*s  %4d/%-3d  %s',
    $name-width, $f.display-path, $f.covered-lines, $f.total-lines, $pct;
    if $color {
      if    $f.percentage >= 90  { $row = green($row) }
      elsif $f.percentage >= 75  { $row = yellow($row) }
      else                       { $row = red($row) }
    }
    @lines.push: $row;
  }

  @lines.push: '-' x $header.chars;
  my $overall = sprintf 'Overall: %d/%d lines (%.1f%%)',
  $report.covered-lines, $report.total-lines, $report.overall-percentage;
  @lines.push: $color ?? bright($overall, $report.overall-percentage) !! $overall;

  if $report.branch {
    my $bline = sprintf 'Branches: %d/%d (%.1f%%)',
    $report.covered-branches, $report.total-branches, $report.overall-branch-percentage;
    @lines.push: $color ?? bright($bline, $report.overall-branch-percentage) !! $bline;
  }

  @lines.join("\n") ~ "\n";
}

our sub bright(Str $s, Real $pct --> Str) {
  return green($s) if $pct >= 90;
  return yellow($s) if $pct >= 75;
  red($s);
}

our sub compress-line-ranges(@nums --> Str) {
  return '' unless @nums;
  my @ranges;
  my $start = @nums[0];
  my $prev  = @nums[0];
  for @nums[1..*] -> $n {
    if $n == $prev + 1 {
      $prev = $n;
    } else {
      @ranges.push: $start == $prev ?? "$start" !! "{$start}-{$prev}";
      $start = $n;
      $prev  = $n;
    }
  }
  @ranges.push: $start == $prev ?? "$start" !! "{$start}-{$prev}";
  @ranges.join(', ');
}

our sub default-html-css(--> Str) {
  q:to/CSS/;
  body { font-family: -apple-system, BlinkMacSystemFont, sans-serif;
         margin: 2em; color: #1a1a1a; }
  h1 { margin: 0 0 0.25em; }
  h2 { margin: 0 0 0.5em; font-size: 1.1em;
       font-family: ui-monospace, SFMono-Regular, Menlo, monospace; }
  a { color: #0366d6; text-decoration: none; }
  a:hover { text-decoration: underline; }
  .summary { font-size: 1.1em; margin-bottom: 1.5em; }
  .back { margin-bottom: 1em; font-size: 0.9em; }
  table { border-collapse: collapse; width: 100%; }
  th, td { padding: 4px 10px; border-bottom: 1px solid #eee; text-align: left;
           vertical-align: top; }
  th { background: #f4f4f6; }
  tr.high   td { background: #e6ffec; }
  tr.medium td { background: #fff7d6; }
  tr.low    td { background: #ffe6e6; }
  .pct { font-weight: bold; text-align: right; }
  pre.source {
    background: #fafafa; border: 1px solid #ddd; padding: 0; margin: 0;
    font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
    font-size: 12px; line-height: 1.3;
    overflow-x: auto;
  }
  .src-line {
    display: block;
    padding: 0 8px;
    white-space: pre;
    line-height: 1.3;
  }
  .src-line.hit  { background: #d3f8d3; }
  .src-line.miss { background: #ffd3d3; }
  .src-line.skip { color: #999; }
  .src-line .ln {
    display: inline-block;
    width: 4em;
    color: #999;
    user-select: none;
    text-align: right;
    margin-right: 1em;
    line-height: 1.3;
  }
  th.sortable { cursor: pointer; user-select: none; }
  th.sortable:hover { background: #e8e8ec; }
  .sort-arrow { color: #666; font-size: 0.85em; margin-left: 0.3em; }
  CSS
}

our sub render-html-index(CoverageReport $report --> Str) {
  my @parts;
  @parts.push: '<!DOCTYPE html>';
  @parts.push: '<html lang="en"><head><meta charset="utf-8">';
  @parts.push: '<title>BDD::Behave Coverage Report</title>';
  @parts.push: '<link rel="stylesheet" href="style.css">';
  @parts.push: '</head><body>';
  @parts.push: '<h1>BDD::Behave Coverage Report</h1>';
  @parts.push: sprintf '<p class="summary">Overall: <strong>%.1f%%</strong> &mdash; %d / %d lines covered',
  $report.overall-percentage, $report.covered-lines, $report.total-lines;
  if $report.branch {
    @parts.push: sprintf '<br>Branches: <strong>%.1f%%</strong> &mdash; %d / %d branches covered',
    $report.overall-branch-percentage, $report.covered-branches, $report.total-branches;
  }
  @parts.push: '</p>';

  @parts.push: '<table id="coverage-table">';
  @parts.push: '<thead><tr>'
  ~ '<th class="sortable" data-sort-type="text">File</th>'
  ~ '<th class="sortable" data-sort-type="num">Lines</th>'
  ~ '<th class="pct sortable" data-sort-type="num">Coverage</th>'
  ~ '</tr></thead>';
  @parts.push: '<tbody>';
  for $report.files -> $f {
    my $klass = $f.percentage >= 90 ?? 'high'
    !! $f.percentage >= 75 ?? 'medium'
    !! 'low';
    @parts.push: sprintf
    '<tr class="%s"><td data-sort="%s"><a href="%s">%s</a></td>'
    ~ '<td data-sort="%d">%d / %d</td>'
    ~ '<td class="pct" data-sort="%.4f">%.1f%%</td></tr>',
    $klass,
    html-escape($f.display-path),
    file-page-name($f.display-path), html-escape($f.display-path),
    $f.total-lines, $f.covered-lines, $f.total-lines,
    $f.percentage, $f.percentage;
  }
  @parts.push: '</tbody></table>';
  @parts.push: index-sort-script();
  @parts.push: '</body></html>';
  @parts.join("\n") ~ "\n";
}

our sub render-html-file-page(FileCoverage $f --> Str) {
  my @parts;
  @parts.push: '<!DOCTYPE html>';
  @parts.push: '<html lang="en"><head><meta charset="utf-8">';
  @parts.push: '<title>' ~ html-escape($f.display-path) ~ ' — Coverage</title>';
  @parts.push: '<link rel="stylesheet" href="style.css">';
  @parts.push: '</head><body>';
  @parts.push: '<p class="back"><a href="index.html">&larr; Back to index</a></p>';
  @parts.push: '<h2>' ~ html-escape($f.display-path) ~ '</h2>';
  @parts.push: sprintf '<p class="summary">%d / %d lines covered (<strong>%.1f%%</strong>)</p>',
  $f.covered-lines, $f.total-lines, $f.percentage;
  @parts.push: render-html-source($f);
  @parts.push: '</body></html>';
  @parts.join("\n") ~ "\n";
}

our sub render-html-source(FileCoverage $f --> Str) {
  my $io = $f.path.IO;
  return '<p><em>(source unavailable)</em></p>' unless $io.e;
  my @rows;
  my %hit-set  = $f.hits.keys.map(* => True);
  my %exec-set = $f.executable.keys.map(* => True);
  for $io.lines.kv -> $idx, $line {
    my $ln = $idx + 1;
    my $klass = !%exec-set{$ln}
    ?? 'skip'
    !! (%hit-set{$ln} ?? 'hit' !! 'miss');
    @rows.push: sprintf '<span class="src-line %s"><span class="ln">%d</span>%s</span>',
    $klass, $ln, html-escape($line);
  }
  '<pre class="source">' ~ @rows.join('') ~ '</pre>';
}

our sub file-page-name(Str $display-path --> Str) {
  html-anchor($display-path) ~ '.html';
}

our sub index-sort-script(--> Str) {
  q:to/JS/;
  <script>
  (function () {
    var table = document.getElementById('coverage-table');
    if (!table) return;
    var ths = table.querySelectorAll('th.sortable');
    var state = { col: -1, asc: true };

    function sortBy(idx, asc, type) {
      var tbody = table.querySelector('tbody');
      var rows = Array.prototype.slice.call(tbody.querySelectorAll('tr'));
      rows.sort(function (a, b) {
        var ca = a.cells[idx], cb = b.cells[idx];
        var va = ca.getAttribute('data-sort');
        var vb = cb.getAttribute('data-sort');
        if (va === null) va = ca.textContent;
        if (vb === null) vb = cb.textContent;
        var cmp;
        if (type === 'num') {
          cmp = parseFloat(va) - parseFloat(vb);
        } else {
          cmp = String(va).localeCompare(String(vb));
        }
        return asc ? cmp : -cmp;
      });
      rows.forEach(function (r) { tbody.appendChild(r); });
    }

    function updateArrows(activeIdx, asc) {
      ths.forEach(function (th, idx) {
        var existing = th.querySelector('.sort-arrow');
        if (existing) existing.remove();
        if (idx === activeIdx) {
          var s = document.createElement('span');
          s.className = 'sort-arrow';
          s.textContent = asc ? '▲' : '▼';
          th.appendChild(s);
        }
      });
    }

    ths.forEach(function (th, idx) {
      th.addEventListener('click', function () {
        var type = th.getAttribute('data-sort-type') || 'text';
        var asc = state.col === idx ? !state.asc : true;
        state = { col: idx, asc: asc };
        sortBy(idx, asc, type);
        updateArrows(idx, asc);
      });
    });
  })();
  </script>
  JS
}

our sub write-html-tree(CoverageReport $report, IO::Path $out-dir --> Nil) {
  $out-dir.mkdir;
  $out-dir.add('style.css').spurt(default-html-css());
  $out-dir.add('index.html').spurt(render-html-index($report));
  for $report.files -> $f {
    $out-dir.add(file-page-name($f.display-path)).spurt(render-html-file-page($f));
  }
}

our sub html-escape(Str $s --> Str) {
  $s.subst('&', '&amp;', :g)
    .subst('<', '&lt;',  :g)
    .subst('>', '&gt;',  :g)
    .subst('"', '&quot;', :g);
}

our sub html-anchor(Str $s --> Str) {
  $s.subst(/<-[A..Za..z0..9-]>/, '-', :g);
}

our sub render-json(CoverageReport $report --> Str) {
  my %summary;
  %summary<lines> = %(
    :total($report.total-lines),
    :covered($report.covered-lines),
    :percentage($report.overall-percentage.Real.round(0.001)),
  );
  if $report.branch {
    %summary<branches> = %(
      :total($report.total-branches),
      :covered($report.covered-branches),
      :percentage($report.overall-branch-percentage.Real.round(0.001)),
    );
  }

  my @files;
  for $report.files -> $f {
    my %row;
    %row<path>                 = $f.display-path;
    %row<absolute-path>        = $f.path;
    %row<total-lines>          = $f.total-lines;
    %row<covered-lines>        = $f.covered-lines;
    %row<percentage>           = $f.percentage.Real.round(0.001);
    %row<missing-lines>        = $f.missing-lines;
    %row<covered-line-numbers> = $f.covered-line-numbers;
    if $report.branch {
      %row<total-branches>     = $f.total-branches;
      %row<covered-branches>   = $f.covered-branches;
      %row<branch-percentage>  = $f.branch-percentage.Real.round(0.001);
    }
    @files.push: %row;
  }

  my %data = :summary(%summary), :@files;
  naive-json(%data);
}

our sub naive-json(Mu $val, Int :$indent = 0 --> Str) {
  my $pad = '  ' x $indent;
  my $npad = '  ' x ($indent + 1);
  given $val {
    when Bool { return $_ ?? 'true' !! 'false' }
    when Numeric { return ~$_ }
    when Str  { return naive-json-str($_) }
    when Positional {
      return '[]' unless $_.elems;
      my @parts = $_.map: { $npad ~ naive-json($_, :indent($indent + 1)) };
      return "[\n" ~ @parts.join(",\n") ~ "\n$pad]";
    }
    when Associative {
      return '{}' unless $_.elems;
      my @parts;
      for $_.keys.sort -> $k {
        my $v = $_{$k};
        next if $v ~~ Nil;
        @parts.push: $npad ~ naive-json-str($k) ~ ': ' ~ naive-json($v, :indent($indent + 1));
      }
      return "\{\n" ~ @parts.join(",\n") ~ "\n$pad\}";
    }
    when Nil { return 'null' }
    default { return naive-json-str(~$_) }
  }
}

our sub naive-json-str(Str $s --> Str) {
  my $escaped = $s
    .subst('\\', '\\\\', :g)
    .subst('"',  '\\"',  :g)
    .subst("\n", '\\n',  :g)
    .subst("\r", '\\r',  :g)
    .subst("\t", '\\t',  :g);
  '"' ~ $escaped ~ '"';
}

our sub render-lcov(CoverageReport $report --> Str) {
  my @out;
  for $report.files -> $f {
    @out.push: 'TN:';
    @out.push: 'SF:' ~ $f.path;
    my @exec = $f.executable.keys.map(*.Int).sort;
    for @exec -> $ln {
      my $hit = $f.hits{$ln} ?? 1 !! 0;
      @out.push: "DA:$ln,$hit";
    }
    @out.push: 'LF:' ~ $f.total-lines;
    @out.push: 'LH:' ~ $f.covered-lines;
    if $report.branch {
      my @br = $f.branch-lines.keys.map(*.Int).sort;
      for @br -> $ln {
        my $hit = $f.branches-hit{$ln} ?? 1 !! 0;
        @out.push: "BRDA:$ln,0,0,$hit";
      }
      @out.push: 'BRF:' ~ $f.total-branches;
      @out.push: 'BRH:' ~ $f.covered-branches;
    }
    @out.push: 'end_of_record';
  }
  @out.join("\n") ~ "\n";
}

our sub render-cobertura(CoverageReport $report --> Str) {
  my $line-rate = $report.total-lines > 0
  ?? ($report.covered-lines / $report.total-lines).Real
  !! 1e0;
  my $branch-rate = $report.total-branches > 0
  ?? ($report.covered-branches / $report.total-branches).Real
  !! 1e0;

  my @out;
  @out.push: '<?xml version="1.0" encoding="UTF-8"?>';
  @out.push: sprintf '<coverage line-rate="%.4f" branch-rate="%.4f" lines-covered="%d" lines-valid="%d" branches-covered="%d" branches-valid="%d" complexity="0" timestamp="%d" version="behave-1.0">',
  $line-rate, $branch-rate,
  $report.covered-lines, $report.total-lines,
  $report.covered-branches, $report.total-branches,
  now.Int;
  @out.push: '<sources><source>' ~ html-escape($report.root.absolute) ~ '</source></sources>';
  @out.push: '<packages><package name="behave-coverage" line-rate="' ~ sprintf('%.4f', $line-rate) ~ '" branch-rate="' ~ sprintf('%.4f', $branch-rate) ~ '" complexity="0">';
  @out.push: '<classes>';
  for $report.files -> $f {
    my $fr = $f.total-lines > 0 ?? ($f.covered-lines / $f.total-lines).Real !! 1e0;
    my $br = $f.total-branches > 0 ?? ($f.covered-branches / $f.total-branches).Real !! 1e0;
    @out.push: sprintf '<class name="%s" filename="%s" line-rate="%.4f" branch-rate="%.4f" complexity="0">',
    html-escape($f.display-path), html-escape($f.display-path), $fr, $br;
    @out.push: '<methods/>';
    @out.push: '<lines>';
    for $f.executable.keys.map(*.Int).sort -> $ln {
      my $hits = $f.hits{$ln} ?? 1 !! 0;
      my $branch = ($report.branch && $f.branch-lines{$ln}) ?? 'true' !! 'false';
      @out.push: sprintf '<line number="%d" hits="%d" branch="%s"/>', $ln, $hits, $branch;
    }
    @out.push: '</lines>';
    @out.push: '</class>';
  }
  @out.push: '</classes>';
  @out.push: '</package></packages>';
  @out.push: '</coverage>';
  @out.join("\n") ~ "\n";
}

our sub render-report(CoverageReport $report, Str $format, Bool :$color = True --> Str) {
  given $format {
    when 'text'      { render-text($report, :$color) }
    when 'json'      { render-json($report) }
    when 'lcov'      { render-lcov($report) }
    when 'cobertura' { render-cobertura($report) }
    when 'html' {
      die "html coverage format writes a directory tree; use write-html-tree";
    }
    default {
      die "Unknown coverage format: '$format' (available: text, html, json, lcov, cobertura)";
    }
  }
}

our sub valid-format(Str $format --> Bool) {
  so $format eq 'text' | 'html' | 'json' | 'lcov' | 'cobertura';
}

# Diff against baseline

our class CoverageDiff {
  has Real $.previous-percentage is rw = 0e0;
  has Real $.current-percentage  is rw = 0e0;
  has Real $.delta               is rw = 0e0;
  has Int  $.newly-covered       is rw = 0;
  has Int  $.newly-uncovered     is rw = 0;
  has      @.regressed-files     is rw;
  has      @.improved-files      is rw;
}

our sub load-baseline(IO::Path $path --> Hash) {
  return %() unless $path.defined && $path.e;
  my $content = $path.slurp;
  parse-baseline-json($content);
}

our sub parse-baseline-json(Str $content --> Hash) {
  # Try JSON::Fast first; fall back to our minimal parser.
  try {
    require ::('JSON::Fast');
    return ::('JSON::Fast').can('from-json').head.($content);
    CATCH { default { } }
  }
  minimal-json-parse($content);
}

our sub minimal-json-parse(Str $content --> Hash) {
  my $pos = 0;
  my $len = $content.chars;

  my &skip-ws = sub () {
    while $pos < $len && $content.substr($pos, 1) ~~ /\s/ { $pos++ }
  };
  my &parse-string;
  my &parse-number;
  my &parse-array;
  my &parse-object;
  my &parse-value;

  &parse-string = sub () {
    skip-ws();
    die "expected string at pos $pos" unless $content.substr($pos, 1) eq '"';
    $pos++;
    my $start = $pos;
    my $buf = '';
    while $pos < $len {
      my $c = $content.substr($pos, 1);
      if $c eq '\\' {
        my $next = $content.substr($pos + 1, 1);
        $buf ~= $content.substr($start, $pos - $start);
        given $next {
          when 'n'  { $buf ~= "\n" }
          when 'r'  { $buf ~= "\r" }
          when 't'  { $buf ~= "\t" }
          when '"'  { $buf ~= '"'  }
          when '\\' { $buf ~= '\\' }
          when '/'  { $buf ~= '/'  }
          default   { $buf ~= $next }
        }
        $pos += 2;
        $start = $pos;
      } elsif $c eq '"' {
        $buf ~= $content.substr($start, $pos - $start);
        $pos++;
        return $buf;
      } else {
        $pos++;
      }
    }
    die "unterminated string";
  };

  &parse-number = sub () {
    my $start = $pos;
    while $pos < $len && $content.substr($pos, 1) ~~ /<[\d.+\-eE]>/ { $pos++ }
    my $s = $content.substr($start, $pos - $start);
    return $s.contains('.') || $s.contains('e') || $s.contains('E')
    ?? $s.Num !! $s.Int;
  };

  &parse-array = sub () {
    $pos++;
    my @arr;
    skip-ws();
    if $content.substr($pos, 1) eq ']' { $pos++; return @arr }
    loop {
      skip-ws();
      @arr.push: parse-value();
      skip-ws();
      my $c = $content.substr($pos, 1);
      if $c eq ',' { $pos++; next }
      elsif $c eq ']' { $pos++; last }
      else { die "expected , or ] at pos $pos" }
    }
    @arr;
  };

  &parse-object = sub () {
    $pos++;
    my %obj;
    skip-ws();
    if $content.substr($pos, 1) eq '}' { $pos++; return %obj }
    loop {
      skip-ws();
      my $k = parse-string();
      skip-ws();
      die "expected : at pos $pos" unless $content.substr($pos, 1) eq ':';
      $pos++;
      skip-ws();
      %obj{$k} = parse-value();
      skip-ws();
      my $c = $content.substr($pos, 1);
      if $c eq ',' { $pos++; next }
      elsif $c eq '}' { $pos++; last }
      else { die "expected , or } at pos $pos" }
    }
    %obj;
  };

  &parse-value = sub () {
    skip-ws();
    return Nil if $pos >= $len;
    my $c = $content.substr($pos, 1);
    if    $c eq '{' { return parse-object() }
    elsif $c eq '[' { return parse-array()  }
    elsif $c eq '"' { return parse-string() }
    elsif $c eq 't' && $content.substr($pos, 4) eq 'true'  { $pos += 4; return True  }
    elsif $c eq 'f' && $content.substr($pos, 5) eq 'false' { $pos += 5; return False }
    elsif $c eq 'n' && $content.substr($pos, 4) eq 'null'  { $pos += 4; return Nil   }
    elsif $c ~~ /<[\d\-]>/ { return parse-number() }
    else { die "unexpected char '$c' at pos $pos" }
  };

  parse-value();
}

our sub compute-diff(CoverageReport $current, IO::Path $baseline --> CoverageDiff) {
  my %prev = load-baseline($baseline);
  my $prev-pct = (%prev<summary><lines><percentage> // 0e0).Real;
  my $cur-pct  = $current.overall-percentage;
  my $diff = CoverageDiff.new(
    :previous-percentage($prev-pct),
    :current-percentage($cur-pct),
    :delta($cur-pct - $prev-pct),
  );

  my %prev-by-path;
  for (%prev<files> // []).list -> $row {
    %prev-by-path{$row<path>} = $row;
  }

  for $current.files -> $f {
    my $prev-row = %prev-by-path{$f.display-path};
    if $prev-row {
      my @prev-covered = ($prev-row<covered-line-numbers> // []).list;
      my %prev-covered-set = @prev-covered.map(* => True);
      my @cur-covered = $f.covered-line-numbers;
      my %cur-covered-set = @cur-covered.map(* => True);

      for @cur-covered -> $ln {
        $diff.newly-covered++ unless %prev-covered-set{$ln};
      }
      for @prev-covered -> $ln {
        $diff.newly-uncovered++ unless %cur-covered-set{$ln};
      }

      my $prev-pct-file = ($prev-row<percentage> // 0e0).Real;
      if $f.percentage < $prev-pct-file - 0.001 {
        $diff.regressed-files.push: %(
          :path($f.display-path),
          :previous($prev-pct-file),
          :current($f.percentage),
        );
      } elsif $f.percentage > $prev-pct-file + 0.001 {
        $diff.improved-files.push: %(
          :path($f.display-path),
          :previous($prev-pct-file),
          :current($f.percentage),
        );
      }
    } else {
      # new file - all covered lines are newly covered
      $diff.newly-covered += $f.covered-lines;
    }
  }
  $diff;
}

our sub render-diff(CoverageDiff $d --> Str) {
  my @out;
  my $arrow = $d.delta > 0.05 ?? '↑'
  !! $d.delta < -0.05 ?? '↓'
  !! '=';
  @out.push: sprintf 'Coverage diff: %.1f%% → %.1f%% (%s%.1f%%)',
  $d.previous-percentage, $d.current-percentage, $arrow, $d.delta.abs;
  @out.push: sprintf '  Newly covered lines:   %d', $d.newly-covered;
  @out.push: sprintf '  Newly uncovered lines: %d', $d.newly-uncovered;
  if $d.regressed-files.elems {
    @out.push: '  Regressed files:';
    for $d.regressed-files.list -> $r {
      @out.push: sprintf '    %s  %.1f%% → %.1f%%', $r<path>, $r<previous>, $r<current>;
    }
  }
  if $d.improved-files.elems {
    @out.push: '  Improved files:';
    for $d.improved-files.list -> $r {
      @out.push: sprintf '    %s  %.1f%% → %.1f%%', $r<path>, $r<previous>, $r<current>;
    }
  }
  @out.join("\n") ~ "\n";
}
