unit module BDD::Behave::Bisect;

use BDD::Behave::Colors;

our class BisectResult {
  has Str @.initial-failing;
  has %.minimal-deps;
  has Int $.iterations = 0;
  has Bool $.had-failures = False;
  has Str $.message;
}

our class Bisector {
  has @.spec-files;
  has Str $.behave-bin = 'bin/behave';
  has @.extra-args;
  has Bool $.verbose = False;
  has Bool $.quiet = False;

  has Int $!iterations = 0;

  method iterations(--> Int) { $!iterations }

  method run(--> BisectResult) {
    self!log: "==> Bisect: initial pass";
    my %initial = self!subprocess-run(:no-only);
    my @executed = %initial<executed>.list.cache;
    my @failed = %initial<failed>.list.cache;

    unless @failed.elems {
      self!log: "Bisect: no failing examples in the initial run. Nothing to do.";
      return BisectResult.new(
        :initial-failing(()),
        :had-failures(False),
        :iterations($!iterations),
        :message('no failures'),
      );
    }

    self!log: "Bisect: {@failed.elems} failing example(s) found across {@executed.elems} executed";
    for @failed -> $f { self!log: "  " ~ red("✗ ") ~ $f }

    my %minimal-deps;
    for @failed -> $failing {
      self!log: "";
      self!log: "==> Bisecting $failing";

      my $idx = @executed.first(* eq $failing, :k);
      unless $idx.defined {
        self!log: "  WARN: $failing not present in execution order, skipping";
        %minimal-deps{$failing} = [];
        next;
      }

      my @prior = @executed[0 ..^ $idx].grep(* ne $failing).List;

      if @prior.elems == 0 {
        self!log: "  No prior examples — failure is independent of order";
        %minimal-deps{$failing} = [];
        next;
      }

      my %isolation = self!subprocess-run(:only-locations([$failing]));
      if %isolation<failed>.first(* eq $failing).defined {
        self!log: "  Failure reproduces in isolation — not order-dependent";
        %minimal-deps{$failing} = [];
        next;
      }

      my %full = self!subprocess-run(:only-locations([|@prior, $failing]));
      unless %full<failed>.first(* eq $failing).defined {
        self!log: "  Failure does not reproduce under --only-example replay; cannot bisect";
        %minimal-deps{$failing} = @prior;
        next;
      }

      my @minimal = self!minimize($failing, @prior);
      %minimal-deps{$failing} = @minimal;

      self!log: "";
      self!log: "  Minimal reproduction ({@minimal.elems} prior + 1 failing):";
      for @minimal -> $m { self!log: "    " ~ light-blue($m) }
      self!log: "    " ~ red($failing) ~ "  (failing)";
      self!log: "";
      self!log: "  Reproduce with:";
      my $cmd = "    bin/behave"
        ~ @minimal.map({ " --only-example $_" }).join
        ~ " --only-example $failing"
        ~ " --order defined"
        ~ @!spec-files.map({ " $_" }).join;
      self!log: $cmd;
    }

    self!log: "";
    self!log: "Bisect complete: {$!iterations} iteration(s)";

    BisectResult.new(
      :initial-failing(@failed),
      :%minimal-deps,
      :had-failures(True),
      :iterations($!iterations),
    );
  }

  method !minimize(Str $failing, @prior --> List) {
    my @current = @prior.List;

    loop {
      last if @current.elems <= 1;
      my $mid = @current.elems div 2;
      my @left = @current[0 ..^ $mid].List;
      my @right = @current[$mid .. *].List;

      my %right-result = self!subprocess-run(
        :only-locations([|@right, $failing]),
      );
      if %right-result<failed>.first(* eq $failing).defined {
        @current = @right;
        self!log: "  shrunk to {@current.elems} prior";
        next;
      }

      my %left-result = self!subprocess-run(
        :only-locations([|@left, $failing]),
      );
      if %left-result<failed>.first(* eq $failing).defined {
        @current = @left;
        self!log: "  shrunk to {@current.elems} prior";
        next;
      }

      last;
    }

    my Bool $changed = True;
    while $changed && @current.elems > 1 {
      $changed = False;
      for ^@current.elems -> $i {
        my @candidate;
        @candidate.append: @current[0 ..^ $i];
        @candidate.append: @current[$i + 1 .. *];
        my %result = self!subprocess-run(
          :only-locations([|@candidate, $failing]),
        );
        if %result<failed>.first(* eq $failing).defined {
          @current = @candidate;
          $changed = True;
          self!log: "  pruned one; {@current.elems} prior remain";
          last;
        }
      }
    }

    @current.List;
  }

  method !subprocess-run(:@only-locations = [], :$no-only = False --> Hash) {
    $!iterations++;

    my @args = '--bisect-data', '--order', 'defined';
    unless $no-only {
      for @only-locations -> $loc {
        @args.append: '--only-example', $loc;
      }
    }
    @args.append: @!extra-args;
    @args.append: @!spec-files;

    if $!verbose {
      note "  [iter $!iterations] raku -Ilib $!behave-bin {@args.join(' ')}";
    }

    my $proc = run('raku', '-Ilib', $!behave-bin, |@args, :out, :err);
    my $out = $proc.out.slurp(:close);
    my $err = $proc.err.slurp(:close);

    my @executed;
    my @failed;
    for $out.lines -> $line {
      if $line.starts-with('behave-executed: ') {
        @executed.push: $line.substr('behave-executed: '.chars);
      } elsif $line.starts-with('behave-failed: ') {
        @failed.push: $line.substr('behave-failed: '.chars);
      }
    }

    %( :@executed, :@failed, :exit($proc.exitcode), :$out, :$err );
  }

  method !log(Str $msg) {
    say $msg unless $!quiet;
  }
}
