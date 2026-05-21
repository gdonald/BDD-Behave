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
}
