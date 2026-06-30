unit module BDD::Behave::Time;

our class Freeze {
  has Instant $.instant is rw;
}

our sub current-freeze() is export {
  my $f;
  try { $f = $*BEHAVE-FROZEN-INSTANT if $*BEHAVE-FROZEN-INSTANT.defined }
  $f;
}

our sub frozen-instant() is export {
  my $f = current-freeze();
  $f.defined ?? $f.instant !! Instant;
}

our sub time-is-frozen(--> Bool) is export {
  current-freeze().defined;
}

our sub current-time() is export {
  my $f = current-freeze();
  $f.defined ?? $f.instant !! now;
}

our sub to-instant($when --> Instant:D) is export {
  return $when                       if $when ~~ Instant;
  return $when.Instant               if $when ~~ DateTime;
  return $when.DateTime.Instant      if $when ~~ Date;
  if $when ~~ Str {
    return DateTime.new($when).Instant;
  }
  if $when ~~ Real {
    return Instant.from-posix($when.Num);
  }
  die "freeze-time: cannot convert {$when.WHAT.^name} to Instant";
}

my $wrapped = False;

sub install-wraps() {
  return if $wrapped;
  $wrapped = True;

  if my $dt-now = DateTime.^lookup('now') {
    $dt-now.wrap(-> $type, *%named {
      my $f = current-freeze();
      if $f.defined {
        my %args = %named;
        %args<timezone> //= $*TZ;
        DateTime.new($f.instant, |%args);
      } else {
        callsame;
      }
    });
  }

  if my $date-today = Date.^lookup('today') {
    $date-today.wrap(-> $type, *%named {
      my $f = current-freeze();
      if $f.defined {
        my %args = %named;
        %args<timezone> //= $*TZ;
        DateTime.new($f.instant, |%args).Date;
      } else {
        # `callsame` here resolves to VMNull for the wrapped Date.today once
        # this module is loaded from precompilation ("lang-call cannot invoke
        # object of type 'VMNull'"). Delegate to the (also wrapped, and working)
        # DateTime.now, which yields the same current local date.
        DateTime.now(|%named).Date;
      }
    });
  }

  try {
    &term:<now>.wrap(-> |args {
      my $f = current-freeze();
      $f.defined ?? $f.instant !! callsame;
    });
  }
}

INIT { install-wraps(); }

our proto sub freeze-time(|) is export {*}

our multi sub freeze-time(&block --> Nil) {
  my $freeze = Freeze.new(:instant(now));
  my $*BEHAVE-FROZEN-INSTANT = $freeze;
  block();
  Nil;
}

our multi sub freeze-time($when, &block --> Nil) {
  my $freeze = Freeze.new(:instant(to-instant($when)));
  my $*BEHAVE-FROZEN-INSTANT = $freeze;
  block();
  Nil;
}

our sub travel-to($when, &block --> Nil) is export {
  my $freeze = Freeze.new(:instant(to-instant($when)));
  my $*BEHAVE-FROZEN-INSTANT = $freeze;
  block();
  Nil;
}

our sub travel-by(Real() $delta --> Nil) is export {
  my $f = current-freeze();
  die "travel-by must be called inside a freeze-time or travel-to block"
    unless $f.defined;
  $f.instant = $f.instant + $delta;
  Nil;
}

