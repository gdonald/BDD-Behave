use BDD::Behave;

# Probe MoarVM's MVM_COVERAGE_CONTROL modes directly: run a tiny module under
# each control value and count the raw HIT lines MoarVM writes for it. This
# documents the practical difference between the modes that behave relies on:
# the default (control=0) captures executed lines with a deduplicated log,
# the opt-in counts mode (control=2) logs every execution, and control=1
# logs nothing for ordinary module code.

my $dir = $*TMPDIR.add("behave-ctrl-spec-{$*PID}-{(now * 1e6).Int}");
$dir.mkdir;

my $mod = $dir.add('CtrlProbe.rakumod');
$mod.spurt(q:to/MOD/);
unit module CtrlProbe;
our sub probe-line($x) is export {
  my $result = $x + 1;
  $result;
}
MOD

my $driver = $dir.add('driver.raku');
$driver.spurt(q:to/DRV/);
use CtrlProbe;
for ^5 { probe-line(41) }
DRV

sub raw-hits-for-control(Str $control --> Int) {
  my $log = $dir.add("cov-$control.raw");
  my %env = %*ENV;
  %env<MVM_COVERAGE_LOG>     = $log.absolute;
  %env<MVM_COVERAGE_CONTROL> = $control;
  run('raku', "-I{$dir.absolute}", $driver.absolute, :!out, :!err, :env(%env));

  my $count = 0;
  if $log.e {
    for $log.lines -> $line {
      $count++ if $line.starts-with('HIT') && $line.contains('CtrlProbe');
    }
    $log.unlink;
  }
  $count;
}

my $hits-control-zero = raw-hits-for-control('0');
my $hits-control-one  = raw-hits-for-control('1');
my $hits-control-two  = raw-hits-for-control('2');

$mod.unlink if $mod.e;
$driver.unlink if $driver.e;
$dir.rmdir if $dir.e && !$dir.dir.elems;

describe 'MVM_COVERAGE_CONTROL modes', {
  it 'captures executed module lines in the default mode (control=0)', {
    expect($hits-control-zero).to.be-greater-than(0);
  }

  it 'logs more rows under the counts mode (control=2) than the deduped default', {
    expect($hits-control-two).to.be-greater-than($hits-control-zero);
  }

  it 'logs nothing for ordinary module code under control=1', {
    expect($hits-control-one).to.be(0);
  }
}
