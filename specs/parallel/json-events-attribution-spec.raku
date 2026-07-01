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

sub failure-message-by-example(*@extra-args --> Hash) {
  my $out = run-behave('--format', 'json-events', '--order', 'defined', |@extra-args, $failing.absolute);

  my %by-description;
  for $out.lines -> $line {
    next unless $line.trim.starts-with('{');
    my %event = parse-json-event($line);
    next unless (%event<type> // '') eq 'example-fail';
    my @failures = (%event<failures> // ()).list;
    %by-description{%event<description>} = @failures ?? (@failures[0]<message> // '').Str !! '';
  }

  %by-description;
}

describe 'json-events per-example failure attribution', {
  context 'running serially', {
    it 'attaches each failure to the example that produced it', {
      my %message = failure-message-by-example();

      aggregate-failures {
        expect(%message{'first example fails'}).to.include('to be: 2');
        expect(%message{'second example fails'}).to.include('to be: b');
        expect(%message{'third example fails'}).to.include('to be: False');
      }
    }
  }

  context 'running across parallel workers', {
    it 'attaches each failure to the example that produced it', {
      my %message = failure-message-by-example('--parallel', '2');

      aggregate-failures {
        expect(%message{'first example fails'}).to.include('to be: 2');
        expect(%message{'second example fails'}).to.include('to be: b');
        expect(%message{'third example fails'}).to.include('to be: False');
      }
    }
  }
}
