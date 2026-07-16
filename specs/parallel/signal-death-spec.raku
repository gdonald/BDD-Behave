use BDD::Behave;

my $root    = $?FILE.IO.parent.parent.parent;
my $lib     = $root.add('lib');
my $bin     = $root.add('bin/behave');
my $fixture = $root.add('t/fixtures/parallel/signal-crash-fixture-spec.raku');

sub strip-ansi(Str $s --> Str) {
  $s.subst(/ \e '[' <[0..9;]>* 'm' /, '', :g);
}

sub run-behave(*@args) {
  my %env = |%*ENV;
  %env<BEHAVE_DISABLE_CONFIG> = '1';
  %env<BEHAVE_WORKER_INDEX>:delete;
  %env<BEHAVE_WORKER_COUNT>:delete;
  my $proc = Proc::Async.new(
    'raku', "-I{$lib.absolute}", $bin.absolute, |@args, :w,
  );
  my $out = '';
  my $err = '';
  $proc.stdout.tap(-> $c { $out ~= $c });
  $proc.stderr.tap(-> $c { $err ~= $c });
  my $done = $proc.start(:ENV(%env));
  $proc.close-stdin;
  my $result = await $done;
  %( :exit($result.exitcode), :$out, :$err );
}

# A worker killed by a real signal must fail the run loudly, never read as
# "0 examples" and success.
describe 'a worker killed by a signal', {
  for <lpt queue isolated> -> $mode {
    it "fails the run and names the signal death in $mode mode", {
      my %r = run-behave('--parallel', '1', "--parallel-mode=$mode", $fixture.absolute);

      aggregate-failures {
        expect(%r<exit> == 0).to.be-falsy;
        expect(strip-ansi(%r<out> ~ %r<err>).contains('died with signal')).to.be-truthy;
      }
    }
  }
}
