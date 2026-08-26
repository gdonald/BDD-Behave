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
describe 'json-events per-example failure attribution', {
  context 'running in the behave process with no workers', {
    let(:failure, { failure-by-example() });

    it 'attaches the first example its own failure line', {
      expect(failure{'first example fails'}<line>).to.be(5);
    }

    it 'attaches the second example its own failure line', {
      expect(failure{'second example fails'}<line>).to.be(9);
    }

    it 'attaches the third example its own failure line', {
      expect(failure{'third example fails'}<line>).to.be(13);
    }

    it 'reports the compared values in the expected and given fields', {
      expect(failure{'first example fails'}<expected>).to.be('2');
    }
  }

  context 'running across parallel workers', {
    let(:failure, { failure-by-example('--parallel', '2') });

    it 'attaches the first example its own failure line', {
      expect(failure{'first example fails'}<line>).to.be(5);
    }

    it 'attaches the second example its own failure line', {
      expect(failure{'second example fails'}<line>).to.be(9);
    }

    it 'attaches the third example its own failure line', {
      expect(failure{'third example fails'}<line>).to.be(13);
    }

    it 'reports the compared values in the message field instead', {
      expect(failure{'first example fails'}<message>).to.include('to be: 2');
    }
  }
}
