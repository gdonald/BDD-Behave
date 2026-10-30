unit module BDD::Behave::LoadProgress;

our constant LOAD-PROGRESS-MARKER is export = 'behave-loading: ';

sub note-progress(Str $text, Bool :$partial --> Nil) is export {
  $partial ?? $*ERR.print($text) !! $*ERR.say($text);
  $*ERR.flush;
}

sub elapsed-text(Real $seconds --> Str) is export {
  sprintf(' (%.1fs)', $seconds);
}

class LoadProgress is export {
  has Int $.total = 0;
  has Str $.noun  = 'spec file';
  has     &.output;
  has     &.clock = { now };
  has     @.loaded;
  has     @.other-lines;
  has Str $!pending = '';
  has     $!started;

  method feed(Str $chunk --> Nil) {
    $!pending ~= $chunk;

    while (my $end = $!pending.index("\n")).defined {
      self!take-line($!pending.substr(0, $end));
      $!pending = $!pending.substr($end + 1);
    }
  }

  method finish(--> Nil) {
    self!take-line($!pending) if $!pending.chars;
    $!pending = '';

    self!close-loading-line;
  }

  method other-text(--> Str) {
    @!other-lines.map(* ~ "\n").join;
  }

  method stall-description(--> Str) {
    return "before loading any $!noun" unless @!loaded;

    my $description = "while loading {@!loaded[*-1]}";
    $description ~= " (loaded after {@!loaded[*-2]})" if @!loaded.elems > 1;
    $description;
  }

  method !take-line(Str $line --> Nil) {
    unless $line.starts-with(LOAD-PROGRESS-MARKER) {
      @!other-lines.push: $line;
      return;
    }

    self!close-loading-line;

    my $file = $line.substr(LOAD-PROGRESS-MARKER.chars);
    @!loaded.push: $file;

    return unless &!output.defined;

    &!output("  [{@!loaded.elems}/$!total] $file", :partial);
    $!started = &!clock();
  }

  method !close-loading-line(--> Nil) {
    return unless $!started.defined;

    &!output(elapsed-text(&!clock() - $!started));
    $!started = Nil;
  }
}
