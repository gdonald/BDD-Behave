use BDD::Behave;
use BDD::Behave::Parallel::EventStream;

describe 'parse-json-event', {
  it 'parses an object with mixed scalar fields', {
    my %ev = parse-json-event('{"type":"example-pass","id":"x:1","duration":0.5}');
    expect(%ev<type>).to.be('example-pass');
    expect(%ev<id>).to.be('x:1');
    expect(%ev<duration>).to.be(0.5);
  }

  it 'parses booleans and null', {
    my %ev = parse-json-event('{"a":true,"b":false,"c":null}');
    expect(%ev<a>).to.be-truthy;
    expect(%ev<b>).to.be-falsy;
    expect(%ev<c>.defined).to.be-falsy;
  }

  it 'parses nested arrays and objects', {
    my %ev = parse-json-event('{"failures":[{"line":42},{"line":7}]}');
    expect(%ev<failures>.elems).to.be(2);
    expect(%ev<failures>[0]<line>).to.be(42);
  }

  it 'handles strings with escapes', {
    my %ev = parse-json-event('{"msg":"line1\nline2","tab":"a\tb"}');
    expect(%ev<msg>).to.be("line1\nline2");
    expect(%ev<tab>).to.be("a\tb");
  }
}

describe 'parse-json-event scanning', {
  it 'parses an escaped quote inside a string', {
    expect(parse-json-event('{"a":"say \"hi\""}')<a>).to.be('say "hi"');
  }

  it 'parses an escaped backslash inside a string', {
    expect(parse-json-event('{"a":"C:\\\\path"}')<a>).to.be('C:\\path');
  }

  it 'parses an escaped forward slash inside a string', {
    expect(parse-json-event('{"a":"\/root"}')<a>).to.be('/root');
  }

  it 'parses the carriage return, backspace, and form feed escapes', {
    expect(parse-json-event('{"a":"x\ry\bz\fw"}')<a>).to.be("x\ry\bz\fw");
  }

  it 'parses a unicode escape', {
    expect(parse-json-event('{"a":"caf\u00e9"}')<a>).to.be('café');
  }

  it 'parses a string that carries no escapes at all', {
    expect(parse-json-event('{"a":"plain text"}')<a>).to.be('plain text');
  }

  it 'parses an empty string value', {
    expect(parse-json-event('{"a":""}')<a>).to.be('');
  }

  it 'parses an empty object', {
    expect(parse-json-event('{}').elems).to.be(0);
  }

  it 'parses an empty array', {
    expect(parse-json-event('{"a":[]}')<a>.elems).to.be(0);
  }

  it 'parses an array of scalars', {
    expect(parse-json-event('{"a":[1,2,3]}')<a>[2]).to.be(3);
  }

  it 'ignores whitespace between tokens', {
    expect(parse-json-event(qq[\{ "a" : \{ "b" : [ 1 , 2 ] \} \}])<a><b>[1]).to.be(2);
  }

  it 'parses a negative integer', {
    expect(parse-json-event('{"a":-42}')<a>).to.be(-42);
  }

  it 'parses a number with a lower-case exponent', {
    expect(parse-json-event('{"a":1.5e2}')<a>).to.be(150e0);
  }

  it 'parses a number with an upper-case exponent and a sign', {
    expect(parse-json-event('{"a":2E+3}')<a>).to.be(2000e0);
  }

  it 'parses a number with a negative exponent', {
    expect(parse-json-event('{"a":5e-1}')<a>).to.be(0.5e0);
  }

  # The scanner walks codepoints, so a multi-byte character before an escape
  # would misplace every later position if the two ever disagreed.
  it 'keeps its place across text outside the ASCII range', {
    expect(parse-json-event('{"a":"héllo\tworld","b":7}')<b>).to.be(7);
  }

  it 'returns the text after a multi-byte character unchanged', {
    expect(parse-json-event('{"a":"héllo\tworld"}')<a>).to.be("héllo\tworld");
  }

  it 'rejects an unknown escape', {
    expect({ parse-json-event('{"a":"\q"}') }).to.throw;
  }

  it 'rejects an unterminated string', {
    expect({ parse-json-event('{"a":"open') }).to.throw;
  }

  it 'rejects a character that starts no value', {
    expect({ parse-json-event('{"a":?}') }).to.throw;
  }

  it 'rejects an object key that is not a string', {
    expect({ parse-json-event('{a:1}') }).to.throw;
  }

  it 'rejects a missing colon after a key', {
    expect({ parse-json-event('{"a" 1}') }).to.throw;
  }

  it 'rejects a missing separator between object members', {
    expect({ parse-json-event('{"a":1 "b":2}') }).to.throw;
  }

  it 'rejects a missing separator between array elements', {
    expect({ parse-json-event('{"a":[1 2]}') }).to.throw;
  }

  it 'rejects a truncated literal', {
    expect({ parse-json-event('{"a":tru}') }).to.throw;
  }

  it 'rejects an empty document', {
    expect({ parse-json-event('') }).to.throw;
  }
}

describe 'JsonLineParser feed/flush', {
  it 'buffers partial lines until a newline arrives', {
    my $parser = BDD::Behave::Parallel::EventStream::JsonLineParser.new;
    my @ev1 = $parser.feed('{"type":"example-pass","id":"a:1"}');
    expect(@ev1.elems).to.be(0);
    my @ev2 = $parser.feed("\n");
    expect(@ev2.elems).to.be(1);
    expect(@ev2[0]<id>).to.be('a:1');
  }

  it 'returns parse-error for malformed JSON', {
    my $parser = BDD::Behave::Parallel::EventStream::JsonLineParser.new;
    my @ev = $parser.feed("not json\n");
    expect(@ev[0]<type>).to.be('parse-error');
  }

  it 'returns parse-error for a stray line that parses as a bare JSON number', {
    my $parser = BDD::Behave::Parallel::EventStream::JsonLineParser.new;
    my @ev = $parser.feed("2026-07-05T02:40:57 info: DELETE FROM posts\n");
    expect(@ev[0]<type>).to.be('parse-error');
  }

  it 'returns parse-error for a stray JSON scalar rather than a raw value', {
    my $parser = BDD::Behave::Parallel::EventStream::JsonLineParser.new;
    my @ev = $parser.feed("42\n");
    expect(@ev[0]<type>).to.be('parse-error');
  }

  it 'flushes the buffered event when no trailing newline arrived', {
    my $parser = BDD::Behave::Parallel::EventStream::JsonLineParser.new;
    $parser.feed('{"type":"example-pass","id":"a:1"}');

    my @ev = $parser.flush;

    aggregate-failures {
      expect(@ev.elems).to.be(1);
      expect(@ev[0]<id>).to.be('a:1');
    }
  }

  it 'flushes a buffered non-object value as a parse-error', {
    my $parser = BDD::Behave::Parallel::EventStream::JsonLineParser.new;
    $parser.feed('42');

    my @ev = $parser.flush;
    expect(@ev[0]<type>).to.be('parse-error');
  }
}
