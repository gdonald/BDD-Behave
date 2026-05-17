unit module BDD::Behave::Benchmark::Baseline;

our constant BASELINE-VERSION = 1;
our constant HEADER-LINE      = '# behave-benchmark-baseline v1';
our constant COLUMN-LINE      = 'description	key	iterations	min	max	mean	median	total';

our class BaselineEntry {
  has Str  $.description is required;
  has Str  $.key         is required;
  has Int  $.iterations  is required;
  has Real $.min         is required;
  has Real $.max         is required;
  has Real $.mean        is required;
  has Real $.median      is required;
  has Real $.total       is required;

  method to-line(--> Str) {
    join "\t",
      $!description,
      $!key,
      $!iterations.Str,
      $!min.Str,
      $!max.Str,
      $!mean.Str,
      $!median.Str,
      $!total.Str;
  }

  method from-line(Str $line --> BaselineEntry) {
    my @fields = $line.split("\t");
    die "baseline line has wrong column count (expected 8, got @fields.elems()): $line"
      unless @fields.elems == 8;
    BaselineEntry.new(
      :description(@fields[0]),
      :key(@fields[1]),
      :iterations(@fields[2].Int),
      :min(@fields[3].Real),
      :max(@fields[4].Real),
      :mean(@fields[5].Real),
      :median(@fields[6].Real),
      :total(@fields[7].Real),
    );
  }
}

our sub serialize(@entries --> Str) {
  my @lines = HEADER-LINE, COLUMN-LINE;
  @lines.append: @entries.map(*.to-line);
  @lines.join("\n") ~ "\n";
}

our sub parse(Str $content --> Array[BaselineEntry]) {
  my @entries;
  my @lines = $content.lines;

  die "empty baseline content"
    unless @lines.elems;

  die "baseline missing header (expected '{HEADER-LINE}')"
    unless @lines[0] eq HEADER-LINE;

  my $saw-columns = False;
  for @lines[1..*] -> $raw {
    next unless $raw.chars;
    next if $raw.starts-with('#');
    unless $saw-columns {
      die "baseline missing column header (expected '{COLUMN-LINE}')"
        unless $raw eq COLUMN-LINE;
      $saw-columns = True;
      next;
    }
    @entries.push: BaselineEntry.from-line($raw);
  }

  my BaselineEntry @result = @entries;
  @result;
}

our sub load(IO::Path $path --> Array[BaselineEntry]) {
  die "baseline file does not exist: $path"
    unless $path.e;
  parse($path.slurp);
}

our sub save(IO::Path $path, @entries --> Nil) {
  $path.spurt: serialize(@entries);
}

our sub index-by-key(@entries --> Hash) {
  my %h;
  for @entries -> $e {
    %h{$e.description}{$e.key} = $e;
  }
  %h;
}
