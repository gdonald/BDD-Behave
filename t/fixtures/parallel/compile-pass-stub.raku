use v6.d;

# Stands in for a `behave --compile-only` subprocess so the precompile pass's
# crash-and-rebuild path is drivable without a real corrupt precomp cache.
# Every invocation appends its argv to BEHAVE_STUB_STATE, so a test can count
# the passes the runner performed and see which files each one covered.

my $state = %*ENV<BEHAVE_STUB_STATE>;
my $invocation = $state.IO.e ?? $state.IO.slurp.lines.elems !! 0;

$state.IO.spurt(@*ARGS.join(' ') ~ "\n", :append);

if $invocation == 0 {
  if %*ENV<BEHAVE_STUB_CRASH_FIRST> {
    run 'kill', '-SEGV', $*PID.Str;
    sleep 30;
  }

  if %*ENV<BEHAVE_STUB_HANG_FIRST> {
    sleep 30;
  }
}

with %*ENV<BEHAVE_COMPILE_REPORT> -> $report {
  for <BEHAVE_STUB_PREFIX BEHAVE_STUB_PREFIX_NO_CACHE> -> $key {
    $report.IO.spurt(%*ENV{$key} ~ "\n", :append) if %*ENV{$key};
  }
}

exit 0;
