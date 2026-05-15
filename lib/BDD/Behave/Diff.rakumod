
unit module BDD::Behave::Diff;

use nqp;
use BDD::Behave::Colors;

proto sub is-junction($) is export {*}
multi sub is-junction(Junction:D --> Bool) { True }
multi sub is-junction($            --> Bool) { False }

sub diff-shape($value) is export {
  return 'Undef' unless $value.defined;
  given $value {
    when Str                { 'Str' }
    when Mix | MixHash      { 'Mix' }
    when Bag | BagHash      { 'Bag' }
    when Set | SetHash      { 'Set' }
    when Associative        { 'Hash' }
    when Positional         { 'Array' }
    default                 { 'Scalar' }
  }
}

proto sub diffable($, $) is export {*}
multi sub diffable($, Junction:D --> Bool) { True }
multi sub diffable($given, $expected --> Bool) {
  return False unless $given.defined && $expected.defined;
  my $sg = diff-shape($given);
  return False unless $sg eq diff-shape($expected);
  so $sg eq any(<Str Array Hash Set Bag Mix>);
}

proto sub render-diff(|) is export {*}
multi sub render-diff($given, Junction:D $expected, Bool :$negated = False --> Str) {
  junction-diff($given, $expected, :$negated);
}
multi sub render-diff($given, $expected, Bool :$negated = False --> Str) {
  given diff-shape($given) {
    when 'Str' { string-diff($given, $expected) }
    default    { structural-diff($given, $expected) }
  }
}

sub string-diff(Str:D $given, Str:D $expected --> Str) {
  if $given.contains("\n") || $expected.contains("\n") {
    return line-level-diff($expected.lines.list, $given.lines.list);
  }
  char-level-diff($given, $expected);
}

sub char-level-diff(Str:D $given, Str:D $expected --> Str) {
  my @g = $given.comb;
  my @e = $expected.comb;

  my $prefix = 0;
  while $prefix < @g.elems && $prefix < @e.elems
        && @g[$prefix] eq @e[$prefix] {
    $prefix++;
  }

  my $g-end = @g.elems;
  my $e-end = @e.elems;
  while $g-end > $prefix && $e-end > $prefix
        && @g[$g-end - 1] eq @e[$e-end - 1] {
    $g-end--;
    $e-end--;
  }

  my $common-pre = $given.substr(0, $prefix);
  my $g-mid      = $given.substr($prefix, $g-end - $prefix);
  my $g-suf      = $given.substr($g-end);
  my $e-mid      = $expected.substr($prefix, $e-end - $prefix);
  my $e-suf      = $expected.substr($e-end);

  my $e-line = '- ' ~ "'" ~ $common-pre
             ~ ($e-mid.chars ?? red($e-mid) !! '')
             ~ $e-suf ~ "'";
  my $g-line = '+ ' ~ "'" ~ $common-pre
             ~ ($g-mid.chars ?? green($g-mid) !! '')
             ~ $g-suf ~ "'";

  $e-line ~ "\n" ~ $g-line;
}

sub line-level-diff(@expected-lines, @given-lines --> Str) {
  my @ops = lcs-diff(@expected-lines.list, @given-lines.list);
  my @out;
  for @ops -> $op {
    my ($kind, $line) = @$op;
    given $kind {
      when '=' { @out.push: '  ' ~ $line }
      when '-' { @out.push: red('- ' ~ $line) }
      when '+' { @out.push: green('+ ' ~ $line) }
    }
  }
  @out.join("\n");
}

sub structural-diff($given, $expected --> Str) {
  line-level-diff(pretty-lines($expected), pretty-lines($given));
}

sub pretty-lines($value, Int :$indent = 0 --> List) is export {
  my $pad = ' ' x $indent;
  given diff-shape($value) {
    when 'Hash'  { hash-pretty($value, $indent) }
    when 'Array' { array-pretty($value, $indent) }
    when 'Set'   { set-pretty($value, $indent) }
    when 'Bag'   { bag-pretty($value, $indent, 'Bag') }
    when 'Mix'   { bag-pretty($value, $indent, 'Mix') }
    default      { ($pad ~ scalar-repr($value),).List }
  }
}

sub scalar-repr($value --> Str) {
  return 'Nil' unless $value.defined;
  $value ~~ Str ?? $value.raku !! $value.gist;
}

sub format-key($k --> Str) {
  $k ~~ Str ?? $k.raku !! $k.gist;
}

sub hash-pretty($value, Int $indent --> List) {
  my $pad     = ' ' x $indent;
  my $inner   = ' ' x ($indent + 2);
  my @keys    = $value.keys.sort(*.gist);
  return ($pad ~ '{}',).List unless @keys;
  my @lines   = $pad ~ '{';
  for @keys -> $k {
    my @sub = pretty-lines($value{$k}, :indent($indent + 2));
    @sub[0] = $inner ~ format-key($k) ~ ' => ' ~ @sub[0].substr($indent + 2);
    @sub[*-1] ~= ',';
    @lines.append: @sub;
  }
  @lines.push: $pad ~ '}';
  @lines.List;
}

sub array-pretty($value, Int $indent --> List) {
  my $pad = ' ' x $indent;
  return ($pad ~ '[]',).List unless $value.elems;
  my @lines = $pad ~ '[';
  for $value.list -> $v {
    my @sub = pretty-lines($v, :indent($indent + 2));
    @sub[*-1] ~= ',';
    @lines.append: @sub;
  }
  @lines.push: $pad ~ ']';
  @lines.List;
}

sub set-pretty($value, Int $indent --> List) {
  my $pad   = ' ' x $indent;
  my $inner = ' ' x ($indent + 2);
  my @keys  = $value.keys.map(*.gist).sort;
  return ($pad ~ 'Set()',).List unless @keys;
  my @lines = $pad ~ 'Set(';
  for @keys -> $k {
    @lines.push: $inner ~ $k ~ ',';
  }
  @lines.push: $pad ~ ')';
  @lines.List;
}

sub bag-pretty($value, Int $indent, Str $name --> List) {
  my $pad   = ' ' x $indent;
  my $inner = ' ' x ($indent + 2);
  my @entries = $value.pairs.map({ format-key(.key) ~ ' => ' ~ .value }).sort;
  return ($pad ~ $name ~ '()',).List unless @entries;
  my @lines = $pad ~ $name ~ '(';
  for @entries -> $e {
    @lines.push: $inner ~ $e ~ ',';
  }
  @lines.push: $pad ~ ')';
  @lines.List;
}

sub junction-kind(Junction:D $j --> Str) is export {
  nqp::box_s(nqp::getattr_s(nqp::decont($j), Junction, q|$!type|), Str);
}

sub junction-eigenstates(Junction:D $j --> List) is export {
  my $e := nqp::getattr(nqp::decont($j), Junction, q|$!eigenstates|);
  (^nqp::elems($e)).map({ nqp::atpos($e, $_) }).list;
}

sub junction-member-repr($v --> Str) {
  $v.defined ?? $v.raku !! $v.^name;
}

sub junction-summary(Str $kind, Int $matched, Int $total, Bool $negated --> Str) {
  given $kind {
    when 'any' {
      $negated
        ?? "Alternatives ($matched of $total matched; expected none under negation):"
        !! "Alternatives (none of $total matched; expected at least one):"
    }
    when 'all' {
      $negated
        ?? "Alternatives ($matched of $total matched; expected at least one to fail under negation):"
        !! "Alternatives ($matched of $total matched; expected all):"
    }
    when 'one' {
      $negated
        ?? "Alternatives ($matched of $total matched; expected zero or more than one under negation):"
        !! "Alternatives ($matched of $total matched; expected exactly one):"
    }
    when 'none' {
      $negated
        ?? "Alternatives ($matched of $total matched; expected at least one under negation):"
        !! "Alternatives ($matched of $total matched; expected zero):"
    }
    default {
      "Alternatives ($matched of $total matched):"
    }
  }
}

sub junction-diff($given, Junction:D $expected, Bool :$negated = False --> Str) is export {
  my $kind    = junction-kind($expected);
  my @members = junction-eigenstates($expected);
  my @results = @members.map({ so ($given ~~ $_) });
  my $matched = @results.grep(*.so).elems;

  my @lines;
  @lines.push: red('- ' ~ $expected.gist);
  @lines.push: green('+ ' ~ scalar-repr($given));
  @lines.push: '  ' ~ junction-summary($kind, $matched, @members.elems, $negated);
  for @members.kv -> $i, $m {
    my $hit  = @results[$i];
    my $mark = $hit ?? green('✓') !! red('✗');
    @lines.push: "    $mark " ~ junction-member-repr($m);
  }
  @lines.join("\n");
}

sub lcs-diff(@a, @b --> List) {
  my $m = @a.elems;
  my $n = @b.elems;

  my @t;
  for 0..$m -> $i { @t[$i][0] = 0; }
  for 0..$n -> $j { @t[0][$j] = 0; }
  for 1..$m -> $i {
    for 1..$n -> $j {
      if @a[$i-1] eq @b[$j-1] {
        @t[$i][$j] = @t[$i-1][$j-1] + 1;
      } else {
        @t[$i][$j] = @t[$i-1][$j] >= @t[$i][$j-1]
                       ?? @t[$i-1][$j]
                       !! @t[$i][$j-1];
      }
    }
  }

  my @ops;
  my ($i, $j) = $m, $n;
  while $i > 0 && $j > 0 {
    if @a[$i-1] eq @b[$j-1] {
      @ops.unshift: ['=', @a[$i-1]];
      $i--; $j--;
    } elsif @t[$i-1][$j] > @t[$i][$j-1] {
      @ops.unshift: ['-', @a[$i-1]];
      $i--;
    } else {
      @ops.unshift: ['+', @b[$j-1]];
      $j--;
    }
  }
  while $i > 0 { @ops.unshift: ['-', @a[$i-1]]; $i--; }
  while $j > 0 { @ops.unshift: ['+', @b[$j-1]]; $j--; }

  @ops.List;
}
