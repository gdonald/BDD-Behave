unit module BDD::Behave::Watch::UI;

use BDD::Behave::Colors;

our class UI {
  has IO::Handle $.in  = $*IN;
  has IO::Handle $.out = $*OUT;
  has Bool       $.color = True;
  has Channel    $!commands .= new;
  has Promise    $!reader;
  has Bool       $!stopped = False;

  method !c(Str $kind, Str $text --> Str) {
    return $text unless $!color;
    given $kind {
      when 'green'  { green($text) }
      when 'red'    { red($text) }
      when 'yellow' { yellow($text) }
      when 'cyan'   { light-blue($text) }
      default       { $text }
    }
  }

  method banner(Str $msg) {
    $.out.say: self!c('cyan', "[behave watch] $msg");
  }

  method info(Str $msg) {
    $.out.say: "[behave watch] $msg";
  }

  method warn(Str $msg) {
    $.out.say: self!c('yellow', "[behave watch] $msg");
  }

  method error(Str $msg) {
    $.out.say: self!c('red', "[behave watch] $msg");
  }

  method prompt() {
    $.out.print: self!c('cyan', '[behave watch] ');
    $.out.print: 'press ';
    $.out.print: self!c('green', 'r');
    $.out.print: ' rerun selection, ';
    $.out.print: self!c('green', 'a');
    $.out.print: ' rerun all, ';
    $.out.print: self!c('green', 'f');
    $.out.print: ' failed only, ';
    $.out.print: self!c('green', 'q');
    $.out.say:   ' quit';
  }

  method change-summary(@changes) {
    my @paths = @changes.map(*.path.basename).unique;
    my $msg = "changes detected: " ~ @paths.join(', ');
    $.out.say: self!c('yellow', "[behave watch] $msg");
  }

  method run-banner(@specs, Str $why) {
    my $count = @specs.elems;
    my $word  = $count == 1 ?? 'spec' !! 'specs';
    $.out.say: self!c('cyan',
      "[behave watch] running $count $word ({$why})");
  }

  method run-finished(Bool $passed) {
    if $passed {
      $.out.say: self!c('green', '[behave watch] passed');
    } else {
      $.out.say: self!c('red', '[behave watch] failed');
    }
  }

  method start-reader() {
    return if $!reader.defined;
    $!reader = start {
      while !$!stopped {
        my $line = $.in.get;
        last unless $line.defined;
        $!commands.send: $line.trim.lc;
      }
    }
  }

  method poll-command(--> Str) {
    $!commands.poll // Str;
  }

  method submit-command(Str $cmd) {
    $!commands.send: $cmd;
  }

  method stop() {
    $!stopped = True;
    try $!commands.close;
  }
}
