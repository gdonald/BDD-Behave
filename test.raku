#!/usr/bin/env raku

use v6.d;

$*OUT.out-buffer = False;

%*ENV<AUTHOR_TESTING> = 1;

chdir $*PROGRAM.parent;

my $cpus            = $*KERNEL.cpu-cores // 2;
my $jobs            = $cpus;
my $behave-parallel = max(2, $cpus - 2);

my @stages = (
  { :name<prove6>, :cmd['prove6', "-j$jobs", '-Ilib', 't']  },
  { :name<behave>, :cmd['raku',   '-Ilib',   'bin/behave', '--parallel', $behave-parallel.Str]  },
);

my %durations;
my $total-start = now;

sub format-ts(--> Str) {
  my $d = DateTime.now;
  sprintf '%04d-%02d-%02d %02d:%02d:%02d',
  $d.year, $d.month, $d.day,
  $d.hour, $d.minute, $d.second.Int;
}

END {
  say '';
  say '==> Runtimes';
  for @stages -> $s {
    next unless %durations{$s<name>}:exists;
    printf "  %-9s %7.2fs\n", $s<name>, %durations{$s<name>};
  }
  printf "  %-9s %7.2fs\n", 'total', (now - $total-start).Num;
}

for @stages -> $s {
  my @cmd = $s<cmd>.list;
  say "==> [{format-ts()}] @cmd.join(' ')";
  my $start = now;
  my $proc  = run(|@cmd);
  %durations{$s<name>} = (now - $start).Num;
  exit $proc.exitcode unless $proc.exitcode == 0;
  say '';
}
