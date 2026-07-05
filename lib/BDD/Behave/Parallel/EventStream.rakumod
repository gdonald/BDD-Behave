unit module BDD::Behave::Parallel::EventStream;

class MiniJsonParser {
  has Str $.text is required;
  has Int $!pos = 0;

  method parse-value {
    self!skip-ws;
    die "unexpected end of input" if $!pos >= $!text.chars;
    my $ch = $!text.substr($!pos, 1);
    given $ch {
      when '{'      { self!parse-object }
      when '['      { self!parse-array  }
      when '"'      { self!parse-string }
      when 't'      { self!parse-literal('true', True) }
      when 'f'      { self!parse-literal('false', False) }
      when 'n'      { self!parse-literal('null', Nil) }
      when /<[-0..9]>/ { self!parse-number }
      default { die "unexpected character '$ch' at $!pos" }
    }
  }

  method !skip-ws {
    while $!pos < $!text.chars && $!text.substr($!pos, 1) ~~ /\s/ {
      $!pos++;
    }
  }

  method !parse-literal(Str $word, $value) {
    if $!text.substr($!pos, $word.chars) eq $word {
      $!pos += $word.chars;
      return $value;
    }
    die "expected '$word' at $!pos";
  }

  method !parse-object {
    my %out;
    $!pos++;
    self!skip-ws;
    if $!text.substr($!pos, 1) eq '}' { $!pos++; return %out }
    loop {
      self!skip-ws;
      die "expected string key at $!pos" unless $!text.substr($!pos, 1) eq '"';
      my $key = self!parse-string;
      self!skip-ws;
      die "expected ':' at $!pos" unless $!text.substr($!pos, 1) eq ':';
      $!pos++;
      self!skip-ws;
      my $value = self.parse-value;
      %out{$key} = $value;
      self!skip-ws;
      my $next = $!text.substr($!pos, 1);
      if $next eq ',' {
        $!pos++;
      } elsif $next eq '}' {
        $!pos++;
        return %out;
      } else {
        die "expected ',' or '\}' at $!pos (got '$next')";
      }
    }
  }

  method !parse-array {
    my @out;
    $!pos++;
    self!skip-ws;
    if $!text.substr($!pos, 1) eq ']' { $!pos++; return @out }
    loop {
      self!skip-ws;
      @out.push(self.parse-value);
      self!skip-ws;
      my $next = $!text.substr($!pos, 1);
      if $next eq ',' {
        $!pos++;
      } elsif $next eq ']' {
        $!pos++;
        return @out;
      } else {
        die "expected ',' or ']' at $!pos (got '$next')";
      }
    }
  }

  method !parse-string {
    die "expected '\"' at $!pos" unless $!text.substr($!pos, 1) eq '"';
    $!pos++;
    my $out = '';
    while $!pos < $!text.chars {
      my $ch = $!text.substr($!pos, 1);
      if $ch eq '"' { $!pos++; return $out }
      if $ch eq '\\' {
        $!pos++;
        my $esc = $!text.substr($!pos, 1);
        $!pos++;
        given $esc {
          when '"'  { $out ~= '"' }
          when '\\' { $out ~= '\\' }
          when '/'  { $out ~= '/'  }
          when 'n'  { $out ~= "\n" }
          when 'r'  { $out ~= "\r" }
          when 't'  { $out ~= "\t" }
          when 'b'  { $out ~= "\b" }
          when 'f'  { $out ~= "\f" }
          when 'u'  {
            my $hex = $!text.substr($!pos, 4);
            $!pos += 4;
            $out ~= chr(:16($hex));
          }
          default { die "bad escape '\\$esc' at $!pos" }
        }
      } else {
        $out ~= $ch;
        $!pos++;
      }
    }
    die "unterminated string at $!pos";
  }

  method !parse-number {
    my $start = $!pos;
    if $!text.substr($!pos, 1) eq '-' { $!pos++ }
    while $!pos < $!text.chars && $!text.substr($!pos, 1) ~~ /<[0..9]>/ {
      $!pos++;
    }
    my $is-float = False;
    if $!pos < $!text.chars && $!text.substr($!pos, 1) eq '.' {
      $is-float = True;
      $!pos++;
      while $!pos < $!text.chars && $!text.substr($!pos, 1) ~~ /<[0..9]>/ {
        $!pos++;
      }
    }
    if $!pos < $!text.chars && $!text.substr($!pos, 1) ~~ /<[eE]>/ {
      $is-float = True;
      $!pos++;
      if $!pos < $!text.chars && $!text.substr($!pos, 1) ~~ /<[-+]>/ { $!pos++ }
      while $!pos < $!text.chars && $!text.substr($!pos, 1) ~~ /<[0..9]>/ {
        $!pos++;
      }
    }
    my $raw = $!text.substr($start, $!pos - $start);
    $is-float ?? $raw.Num !! $raw.Int;
  }
}

sub parse-json-event(Str $line) is export {
  my $parser = MiniJsonParser.new(:text($line));
  $parser.parse-value;
}

class JsonLineParser is export {
  has Str $!buffer = '';

  method feed(Str $chunk --> List) {
    my @events;
    return @events.List unless $chunk.defined && $chunk.chars;
    $!buffer ~= $chunk;
    while $!buffer.contains("\n") {
      my $idx = $!buffer.index("\n");
      my $line = $!buffer.substr(0, $idx);
      $!buffer = $!buffer.substr($idx + 1);
      my $trimmed = $line.trim;
      next unless $trimmed.chars;
      my $event = try parse-json-event($trimmed);
      @events.push: $event ~~ Associative ?? $event !! %( :type<parse-error>, :raw($trimmed) );
    }
    @events.List;
  }

  method flush(--> List) {
    my @events;
    my $trimmed = $!buffer.trim;
    $!buffer = '';
    if $trimmed.chars {
      my $event = try parse-json-event($trimmed);
      @events.push: $event ~~ Associative ?? $event !! %( :type<parse-error>, :raw($trimmed) );
    }
    @events.List;
  }
}
