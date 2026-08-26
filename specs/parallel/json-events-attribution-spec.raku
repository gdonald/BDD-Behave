use BDD::Behave;
use BDD::Behave::Parallel::EventStream;

my $root    = $?FILE.IO.parent.parent.parent;
my $lib     = $root.add('lib');
my $bin     = $root.add('bin/behave');
my $failing = $root.add('t/fixtures/failing-fixture-spec.raku');

sub run-behave(*@args) {
  my %env = |%*ENV;
  %env<BEHAVE_DISABLE_CONFIG> = '1';
  my $proc = Proc::Async.new(
    'raku', "-I{$lib.absolute}", $bin.absolute, |@args, :w,
  );
  my $out = '';
  $proc.stdout.tap(-> $c { $out ~= $c });
  $proc.stderr.tap(-> $c { });
  my $done = $proc.start(:%env);
  $proc.close-stdin;
  my $completed = await $done;
  $out;
}

sub failure-by-example(*@extra-args --> Hash) {
  my $out = run-behave('--format', 'json-events', '--order', 'defined', |@extra-args, $failing.absolute);

  my %by-description;
  for $out.lines -> $line {
    next unless $line.trim.starts-with('{');
    my %event = parse-json-event($line);
    next unless (%event<type> // '') eq 'example-fail';
    my @failures = (%event<failures> // ()).list;
    %by-description{%event<description>} = @failures ?? @failures[0] !! %();
  }

  %by-description;
}

# The fixture's three examples fail on distinct lines, so the reported line is
# what ties a failure back to the example that produced it.
# One subprocess per context, shared by every example the context registers.
sub run-once(&produce) {
  my %cache;
  my $produced = False;

  -> {
    unless $produced {
      %cache = produce();
      $produced = True;
    }

    %cache;
  }
}

shared-examples 'a per-example failure record', -> &failure {
  it 'attaches the first example its own failure line', {
    expect(failure{'first example fails'}<line>).to.be(5);
  }

  it 'attaches the second example its own failure line', {
    expect(failure{'second example fails'}<line>).to.be(9);
  }

  it 'attaches the third example its own failure line', {
    expect(failure{'third example fails'}<line>).to.be(13);
  }

  it 'reports the value the example was given', {
    expect(failure{'first example fails'}<given>).to.be('1');
  }

  it 'reports the value the example expected', {
    expect(failure{'first example fails'}<expected>).to.be('2');
  }

  it 'reports the comparison as a rendered message as well', {
    expect(failure{'first example fails'}<message>).to.be("Expected: 1\nto be: 2");
  }

  it 'reports whether the expectation was negated', {
    expect(failure{'first example fails'}<negated>).to.be-falsy;
  }
}

describe 'json-events per-example failure attribution', {
  context 'running in the behave process with no workers', {
    it-behaves-like 'a per-example failure record',
      run-once({ failure-by-example() });
  }

  context 'running across parallel workers', {
    it-behaves-like 'a per-example failure record',
      run-once({ failure-by-example('--parallel', '2') });
  }
}
