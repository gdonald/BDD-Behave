use v6.d;

# Stands in for a `behave --compile-only` subprocess so the precompile pass's
# crash-and-rebuild path is drivable without a real corrupt precomp cache.
# Every invocation appends its argv to BEHAVE_STUB_STATE, so a test can count
# the passes the runner performed and see which files each one covered.

my $state = %*ENV<BEHAVE_STUB_STATE>;
my $invocation = $state.IO.e ?? $state.IO.slurp.lines.grep({ !.contains('--compile-modules=') }).elems !! 0;

$state.IO.spurt(@*ARGS.join(' ') ~ "\n", :append);

with @*ARGS.first(*.starts-with('--compile-modules=')) -> $arg {
  my $meta = $arg.substr('--compile-modules='.chars).IO;
  my @modules = $meta.slurp.lines.map({ ~$0 if / '"' (<[\w:]>+) '": "' / }).grep(*.defined);

  for @modules -> $module {
    $*ERR.say("behave-loading: $module");
    $*ERR.flush;
  }

  run 'kill', '-SEGV', $*PID.Str if %*ENV<BEHAVE_STUB_CRASH_MODULES>;
  sleep 30 if %*ENV<BEHAVE_STUB_HANG_MODULES> || %*ENV<BEHAVE_STUB_CRASH_MODULES>;
  exit 0;
}

if %*ENV<BEHAVE_LOAD_PROGRESS> {
  for @*ARGS.grep(*.ends-with('-spec.raku')) -> $file {
    $*ERR.say("behave-loading: $file");
    $*ERR.flush;
  }
}

if %*ENV<BEHAVE_STUB_HANG_UNION> && @*ARGS.grep(*.ends-with('-spec.raku')).elems > 1 {
  sleep 30;
}

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
