unit module Behave::Test::ProjectDir;

my $behave-root = $?FILE.IO.parent.parent.parent.parent.parent;

sub make-project(%files --> IO::Path) is export {
  my $dir = $*TMPDIR.add("behave-project-{$*PID}-{(now * 1e6).Int}");

  for %files.kv -> $relative, $content {
    my $path = $dir.add($relative);
    $path.parent.mkdir;
    $path.spurt($content);
  }

  $dir;
}

sub remove-project(IO::Path $dir --> Nil) is export {
  for $dir.dir -> $entry {
    $entry.d && !$entry.l ?? remove-project($entry) !! $entry.unlink;
  }
  $dir.rmdir;
}

sub run-behave-in(IO::Path $dir, *@args, :@include --> Hash) is export {
  my %env = |%*ENV;
  %env<BEHAVE_DISABLE_CONFIG>:delete;
  %env<RAKULIB>:delete;
  %env<BEHAVE_WORKER_INDEX>:delete;
  %env<BEHAVE_WORKER_COUNT>:delete;

  my @include-flags = |@include.map({ "-I{$dir.add($_).absolute}" }), "-I{$behave-root.add('lib').absolute}";

  my $proc = run(
    'raku', |@include-flags, $behave-root.add('bin/behave').absolute,
    '--no-user-config', |@args,
    :cwd($dir), :env(%env), :out, :err,
  );

  my $out = $proc.out.slurp(:close);
  my $err = $proc.err.slurp(:close);

  %( :exit($proc.exitcode), :$out, :$err );
}

sub run-project(%files, *@args, :@include --> Hash) is export {
  my $dir    = make-project(%files);
  my %result = run-behave-in($dir, |@args, :@include);

  remove-project($dir);
  %result;
}
