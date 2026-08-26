unit module BDD::Behave::Parallel::EventStream;

# Every event line from every worker is parsed here. The scan compares single
# characters rather than matching a regex per character, caches the length, and
# finds the end of a string with `index` so a string with no escape in it is cut
# out in one piece.
class MiniJsonParser {
  has Str $.text is required;
  has int $!pos = 0;
  has int $!len = 0;

  submethod TWEAK { $!len = $!text.chars }

  method !at(int $offset --> Str) {
    $offset < $!len ?? $!text.substr($offset, 1) !! '';
  }

  method parse-value {
    self!skip-ws;
    die "unexpected end of input" if $!pos >= $!len;

    my $ch = $!text.substr($!pos, 1);

    return self!parse-object if $ch eq '{';
    return self!parse-array  if $ch eq '[';
    return self!parse-string if $ch eq '"';
    return self!parse-number if $ch eq '-' || ('0' le $ch le '9');

    given $ch {
      when 't' { self!parse-literal('true', True) }
      when 'f' { self!parse-literal('false', False) }
      when 'n' { self!parse-literal('null', Nil) }
      default  { die "unexpected character '$ch' at $!pos" }
    }
  }

  method !skip-ws {
    while $!pos < $!len {
      my $ch = $!text.substr($!pos, 1);
      last unless $ch eq ' ' || $ch eq "\t" || $ch eq "\n" || $ch eq "\r";
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

    if self!at($!pos) eq '}' { $!pos++; return %out }

    loop {
      self!skip-ws;
      die "expected string key at $!pos" unless self!at($!pos) eq '"';

      my $key = self!parse-string;
      self!skip-ws;

      die "expected ':' at $!pos" unless self!at($!pos) eq ':';
      $!pos++;
      self!skip-ws;

      %out{$key} = self.parse-value;
      self!skip-ws;

      my $next = self!at($!pos);
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

    if self!at($!pos) eq ']' { $!pos++; return @out }

    loop {
      self!skip-ws;
      @out.push(self.parse-value);
      self!skip-ws;

      my $next = self!at($!pos);
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

  # The closing quote and the first backslash are both found with `index`. When
  # no backslash comes first the whole string is one substr, and otherwise each
  # run between escapes is, so no path appends a character at a time.
  method !parse-string {
    die "expected '\"' at $!pos" unless self!at($!pos) eq '"';
    $!pos++;

    my int $from = $!pos;
    my @pieces;

    loop {
      my $quote = $!text.index('"', $from);
      die "unterminated string at $from" without $quote;

      my $escape = $!text.index('\\', $from);

      if !$escape.defined || $escape > $quote {
        $!pos = $quote + 1;
        my $tail = $!text.substr($from, $quote - $from);

        return @pieces.elems ?? @pieces.join ~ $tail !! $tail;
      }

      @pieces.push($!text.substr($from, $escape - $from));

      my $esc = self!at($escape + 1);
      $from = $escape + 2;

      given $esc {
        when '"'  { @pieces.push('"')  }
        when '\\' { @pieces.push('\\') }
        when '/'  { @pieces.push('/')  }
        when 'n'  { @pieces.push("\n") }
        when 'r'  { @pieces.push("\r") }
        when 't'  { @pieces.push("\t") }
        when 'b'  { @pieces.push("\b") }
        when 'f'  { @pieces.push("\f") }
        when 'u'  {
          @pieces.push(chr(:16($!text.substr($from, 4))));
          $from += 4;
        }
        default { die "bad escape '\\$esc' at {$escape + 1}" }
      }
    }
  }

  method !parse-number {
    my int $start = $!pos;
    $!pos++ if self!at($!pos) eq '-';

    self!skip-digits;

    my Bool $is-float = False;

    if self!at($!pos) eq '.' {
      $is-float = True;
      $!pos++;
      self!skip-digits;
    }

    my $exponent = self!at($!pos);
    if $exponent eq 'e' || $exponent eq 'E' {
      $is-float = True;
      $!pos++;

      my $sign = self!at($!pos);
      $!pos++ if $sign eq '-' || $sign eq '+';

      self!skip-digits;
    }

    my $raw = $!text.substr($start, $!pos - $start);

    $is-float ?? $raw.Num !! $raw.Int;
  }

  method !skip-digits {
    while $!pos < $!len {
      my $ch = $!text.substr($!pos, 1);
      last unless '0' le $ch le '9';
      $!pos++;
    }
  }
}

sub parse-json-event(Str $line) is export {
  my $parser = MiniJsonParser.new(:text($line));
  $parser.parse-value;
}

class JsonLineParser is export {
  has Str $!buffer = '';

  # A chunk carrying N lines is walked with a moving offset and the remainder is
  # sliced once at the end, so the cost stays linear in the chunk rather than
  # re-copying what is left after every line.
  method feed(Str $chunk --> List) {
    my @events;
    return @events.List unless $chunk.defined && $chunk.chars;

    $!buffer ~= $chunk;

    my int $from = 0;
    loop {
      my $break = $!buffer.index("\n", $from);
      last without $break;

      my $trimmed = $!buffer.substr($from, $break - $from).trim;
      $from = $break + 1;

      next unless $trimmed.chars;

      my $event = try parse-json-event($trimmed);
      @events.push: $event ~~ Associative ?? $event !! %( :type<parse-error>, :raw($trimmed) );
    }

    $!buffer = $!buffer.substr($from) if $from;

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
