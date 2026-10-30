unit module Behave::Test::CompilePassStub;

use BDD::Behave::Parallel;

# Drives precompile-specs-serially against a stub subprocess instead of a real
# `behave --compile-only`, so the crash-and-rebuild path can be exercised
# without a genuinely corrupt precomp cache.

class ProgressCapture is export {
  has @.lines;
  has Str $!partial-line = q{};

  method record(Str $text, Bool :$partial) {
    $!partial-line ~= $text;
    return if $partial;

    @!lines.push: $!partial-line;
    $!partial-line = q{};
  }
}

class StubRun is export {
  has IO::Path $.sandbox;
  has IO::Path $.state-file;
  has IO::Path $.cache-prefix;
  has IO::Path $.no-cache-prefix;
  has          @.spec-files;
  has          $.stall is rw;
  has          $.result is rw;
  has ProgressCapture $.progress = ProgressCapture.new;

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
  :$hang-every-union  = False,
  :$hang-modules      = False,
  :$crash-modules     = False,
  :@modules,
  :&parallel-runner,
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

  my $meta-file = $sandbox.add('META6.json');
  if @modules {
    my $provides = @modules.map({ "    \"$_\": \"lib/$_.rakumod\"" }).join(",\n");
    $meta-file.spurt("\{\n  \"provides\": \{\n$provides\n  }\n}\n");
  }

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
  %env<BEHAVE_STUB_HANG_UNION>  = '1' if $hang-every-union;
  %env<BEHAVE_STUB_HANG_MODULES> = '1' if $hang-modules;
  %env<BEHAVE_STUB_CRASH_MODULES> = '1' if $crash-modules;

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

  my &progress = -> $text, Bool :$partial { $run.progress.record($text, :$partial) };

  if &parallel-runner.defined {
    $run.result = parallel-runner(
      :spec-files($run.spec-files.map(*.absolute)),
      :discovery-argv(('raku', $stub.absolute)),
      :base-env(%env),
      :&progress,
      :$meta-file,
    );
    return $run;
  }

  $run.stall = precompile-specs-serially(
    $run.spec-files,
    :discovery-argv(('raku', $stub.absolute)),
    :base-env(%env),
    :&progress,
    :clock({ 0 }),
    :$meta-file,
  );

  $run;
}
