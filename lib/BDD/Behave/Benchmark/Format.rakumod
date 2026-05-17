unit module BDD::Behave::Benchmark::Format;

sub json-string(Str $s --> Str) {
  my $body = $s;
  $body = $body.subst('\\', '\\\\', :g);
  $body = $body.subst('"', '\\"', :g);
  $body = $body.subst("\b", '\\b',  :g);
  $body = $body.subst("\f", '\\f',  :g);
  $body = $body.subst("\n", '\\n',  :g);
  $body = $body.subst("\r", '\\r',  :g);
  $body = $body.subst("\t", '\\t',  :g);
  '"' ~ $body ~ '"';
}

sub json-number($n --> Str) {
  my $v = $n.Real;
  return 'null' unless $v.defined;
  $v.Str;
}

our sub to-json($value --> Str) {
  given $value {
    when Bool       { $value ?? 'true' !! 'false' }
    when Numeric    { json-number($value) }
    when Str        { json-string($value) }
    when Positional { '[' ~ $value.list.map(&to-json).join(',') ~ ']' }
    when Associative {
      my @keys = $value.keys.sort;
      '{' ~ @keys.map(-> $k {
        json-string($k.Str) ~ ':' ~ to-json($value{$k})
      }).join(',') ~ '}';
    }
    default {
      return 'null' unless $value.defined;
      json-string($value.Str);
    }
  }
}

our sub format-bench-summary(@summaries --> Hash) {
  my @rows;
  for @summaries -> %s {
    my $ex = %s<example>;
    @rows.push: {
      description => %s<description>,
      key         => %s<key>,
      label       => (%s<label>    // Str),
      position    => (%s<position> // Int),
      iterations  => %s<iterations>,
      runs        => (%s<runs> // 1),
      min         => %s<min>.Real,
      max         => %s<max>.Real,
      mean        => %s<mean>.Real,
      median      => %s<median>.Real,
      total       => %s<total>.Real,
      file        => ($ex.defined ?? $ex.file.Str !! Str),
      line        => ($ex.defined ?? $ex.line     !! Int),
    };
  }
  %( benchmarks => @rows );
}

our sub format-bench-regressions(@regressions --> Hash) {
  my @rows;
  for @regressions -> %r {
    @rows.push: {
      description     => %r<description>,
      key             => %r<key>,
      current-median  => %r<median>.Real,
      baseline-median => %r<baseline-median>.Real,
      delta-pct       => %r<delta-pct>.Real,
      regression      => %r<regression>.so,
    };
  }
  %( regressions => @rows );
}

our sub to-json-document(@summaries, @regressions, Real $threshold --> Str) {
  my %summary    = format-bench-summary(@summaries);
  my %regression = format-bench-regressions(@regressions);
  my %doc = (
    version     => 1,
    threshold   => $threshold.Real,
    benchmarks  => %summary<benchmarks>,
    regressions => %regression<regressions>,
  );
  to-json(%doc);
}

sub strip-ansi(Str $s --> Str) {
  $s.subst(/\e '[' \d+ 'm'/, '', :g);
}

our sub visible-width(Str $s --> Int) {
  strip-ansi($s).chars;
}

our sub pad-right(Str $s, Int $width --> Str) {
  my $pad = $width - visible-width($s);
  $pad > 0 ?? $s ~ (' ' x $pad) !! $s;
}

our sub pad-left(Str $s, Int $width --> Str) {
  my $pad = $width - visible-width($s);
  $pad > 0 ?? (' ' x $pad) ~ $s !! $s;
}

our sub render-table(@headers, @rows, @widths, @aligns --> Str) {
  my @lines;

  my @header-cells;
  for ^@headers.elems -> $i {
    @header-cells.push: @aligns[$i] eq 'right'
      ?? pad-left(@headers[$i], @widths[$i])
      !! pad-right(@headers[$i], @widths[$i]);
  }
  @lines.push: '  ' ~ @header-cells.join('  ');

  my @rule-cells = @widths.map({ '─' x $_ });
  @lines.push: '  ' ~ @rule-cells.join('  ');

  for @rows -> @row {
    my @cells;
    for ^@row.elems -> $i {
      @cells.push: @aligns[$i] eq 'right'
        ?? pad-left(@row[$i], @widths[$i])
        !! pad-right(@row[$i], @widths[$i]);
    }
    @lines.push: '  ' ~ @cells.join('  ');
  }
  @lines.join("\n");
}

our sub column-widths(@headers, @rows --> List) {
  my @widths = @headers.map(&visible-width);
  for @rows -> @row {
    for ^@row.elems -> $i {
      my $w = visible-width(@row[$i]);
      @widths[$i] = $w if $w > @widths[$i];
    }
  }
  @widths.List;
}
