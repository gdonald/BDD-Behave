unit module Behave::Test::CompilePassStub;

use BDD::Behave::Parallel;

# Drives precompile-specs-serially against a stub subprocess instead of a real
# `behave --compile-only`, so the crash-and-rebuild path can be exercised
# without a genuinely corrupt precomp cache.

class StubRun is export {
  has IO::Path $.sandbox;
  has IO::Path $.state-file;
  has IO::Path $.cache-prefix;
  has IO::Path $.no-cache-prefix;
  has          @.spec-files;

  method invocations() {
    $!state-file.e ?? $!state-file.slurp.lines !! ();
  }

  method pass-count() { self.invocations.elems }

  method precomp-dir() { $!cache-prefix.add('.precomp') }

  method precomp-exists() { self.precomp-dir.d }

  method cleanup() {
    my sub prune(IO::Path $dir) {
      for $dir.dir -> $entry {
        $entry.d ?? prune($entry) !! (try $entry.unlink);
      }
      try $dir.rmdir;
    }
    prune($!sandbox) if $!sandbox.d;
  }
}

sub make-stub-run(
  :$crash             = False,
  :$hang              = False,
  :$report-prefixes   = True,
  :$spec-file-count   = 2,
  :$timeout,
  --> StubRun
) is export {
  my $stub = $?FILE.IO.parent.parent.parent.parent.parent
                  .add('t/fixtures/parallel/compile-pass-stub.raku');

  my $sandbox = $*TMPDIR.add("behave-compile-pass-{$*PID}-{(now * 1e6).Int}");
  $sandbox.mkdir;

  my $state-file = $sandbox.add('passes');

  # A project lib dir whose .precomp cache the pass should clear, and one with
  # no cache at all, which the pass should skip over.
  my $cache-prefix = $sandbox.add('project-lib');
  $cache-prefix.add('.precomp/nested').mkdir;
  $cache-prefix.add('.precomp/nested/unit').spurt('stale');
  $cache-prefix.add('.precomp/CACHEDIR.TAG').spurt('Signature: 8a477f597d28d172789f06886806bc55');

  my $no-cache-prefix = $sandbox.add('cacheless-lib');
  $no-cache-prefix.mkdir;

  my @spec-files = (^$spec-file-count).map(-> $index { $sandbox.add("file-{$index}-spec.raku") });
  .spurt('') for @spec-files;

  my $run = StubRun.new(
    :$sandbox,
    :$state-file,
    :$cache-prefix,
    :$no-cache-prefix,
    :@spec-files,
  );

  my %env = |%*ENV;
  %env<BEHAVE_STUB_STATE> = $state-file.absolute;
  %env<BEHAVE_STUB_CRASH_FIRST> = '1' if $crash;
  %env<BEHAVE_STUB_HANG_FIRST>  = '1' if $hang;

  if $report-prefixes {
    %env<BEHAVE_STUB_PREFIX>          = $cache-prefix.absolute;
    %env<BEHAVE_STUB_PREFIX_NO_CACHE> = $no-cache-prefix.absolute;
  }

  my $saved-timeout = %*ENV<BEHAVE_DISCOVERY_TIMEOUT>;
  %*ENV<BEHAVE_DISCOVERY_TIMEOUT> = $timeout if $timeout.defined;

  LEAVE {
    $saved-timeout.defined
      ?? (%*ENV<BEHAVE_DISCOVERY_TIMEOUT> = $saved-timeout)
      !! (%*ENV<BEHAVE_DISCOVERY_TIMEOUT>:delete);
  }

  precompile-specs-serially(
    $run.spec-files,
    :discovery-argv(('raku', $stub.absolute)),
    :base-env(%env),
  );

  $run;
}
