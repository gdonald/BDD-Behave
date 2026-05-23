use BDD::Behave;

my $root    = $?FILE.IO.parent.parent.parent;
my $bin     = $root.add('bin/behave');
my $fixture = $root.add('t/fixtures/dry-run/sample-fixture-spec.raku');

sub run-behave(*@args) {
  my $proc = run('raku', '-Ilib', $bin.absolute, |@args,
                 :out, :err, :env(|%*ENV, BEHAVE_DISABLE_CONFIG => '1'));
  my $out = $proc.out.slurp(:close);
  my $err = $proc.err.slurp(:close);
  %( :exit($proc.exitcode), :$out, :$err );
}

describe 'bin/behave --list-examples', {
  it 'mentions --list-examples in --help', {
    my %r = run-behave('--help');
    expect(%r<out>).to.include('--list-examples');
  }

  it 'emits one FILE:LINE line per example by default', {
    my %r = run-behave('--list-examples', $fixture.absolute);
    expect(%r<exit>).to.be(0);
    my @lines = %r<out>.lines.grep({ $_.chars });
    expect(@lines.elems).to.eq(5);
    for @lines -> $line {
      expect($line).to.include("\t");
      expect($line).to.include('sample-fixture-spec.raku:');
    }
  }

  it 'includes the joined full description in text mode', {
    my %r = run-behave('--list-examples', $fixture.absolute);
    expect(%r<out>).to.include('Cart adding items increments the count');
    expect(%r<out>).to.include('Cart removing items decrements the count');
  }

  it 'emits a JSON document under --list-examples-format=json', {
    my %r = run-behave('--list-examples', '--list-examples-format=json',
                       $fixture.absolute);
    expect(%r<exit>).to.be(0);
    expect(%r<out>).to.include('"version":1');
    expect(%r<out>).to.include('"count":5');
    expect(%r<out>).to.include('"description":"increments the count"');
    expect(%r<out>).to.include('"line":5');
    expect(%r<out>).to.include('"tags":["fast"]');
    expect(%r<out>).to.include('"pending":true');
    expect(%r<out>).to.include('"skipped":true');
  }

  it 'rejects an unknown --list-examples-format with exit 2', {
    my %r = run-behave('--list-examples', '--list-examples-format=xml',
                       $fixture.absolute);
    expect(%r<exit>).to.be(2);
    expect(%r<err>).to.include("--list-examples-format must be 'text' or 'json'");
  }

  it 'honors --tag', {
    my %r = run-behave('--list-examples', '--tag', 'fast', $fixture.absolute);
    expect(%r<exit>).to.be(0);
    expect(%r<out>).to.include('increments the count');
    expect(%r<out>.contains('decrements the count')).to.be-falsy;
  }

  it 'honors --exclude-tag', {
    my %r = run-behave('--list-examples', '--exclude-tag', 'fast', $fixture.absolute);
    expect(%r<out>.contains('increments the count')).to.be-falsy;
    expect(%r<out>).to.include('decrements the count');
  }

  it 'honors --example pattern', {
    my %r = run-behave('--list-examples', '--example', 'decrements', $fixture.absolute);
    expect(%r<exit>).to.be(0);
    my @lines = %r<out>.lines.grep({ $_.chars });
    expect(@lines.elems).to.eq(1);
    expect(@lines[0]).to.include('decrements the count');
  }

  it 'honors --only-example FILE:LINE', {
    my %r = run-behave('--list-examples', '--only-example',
                       "{$fixture.absolute}:5", $fixture.absolute);
    my @lines = %r<out>.lines.grep({ $_.chars });
    expect(@lines.elems).to.eq(1);
    expect(@lines[0]).to.include('increments the count');
  }

  it 'returns an empty list when no examples match', {
    my %r = run-behave('--list-examples', '--example',
                       'never-matches', $fixture.absolute);
    expect(%r<exit>).to.be(0);
    expect(%r<out>.lines.grep({ $_.chars }).elems).to.eq(0);
  }
}
