
use MONKEY-SEE-NO-EVAL;

use BDD::Behave::Actions;
use BDD::Behave::Colors;
use BDD::Behave::Failures;
use BDD::Behave::Files;
use BDD::Behave::Grammar;

class Behave {
  has @!specs of Str;
  has Bool $!verbose;

  submethod BUILD(:$!verbose, :@!specs) {
    self.run
  }

  method run {
    for Files.list(@!specs) -> $file {
      Files.current = $file;
      say "\n" ~ light-blue($file);
      self.eval-file(:$file);
    }

    say '';
    Failures.say;
  }

  method eval-file(:$file) {
    if $file ~~ /\: \d+$/ {
      self.eval-partial-file(:$file);
    } else {
      Grammar.parse($file.IO.slurp.trim, :actions(Actions));
    }
  }

  method eval-partial-file(:$file) {
    my ($path, $line) = $file.split(':');
    Grammar.parse($path.IO.slurp.trim, :actions(Actions));
  }
}

sub run-behave(:$verbose, :@specs) is export { Behave.new(:$verbose, :@specs) }

sub describe(|args) is export {
  state $impl = do {
    require ::('BDD::Behave::DSL');
    ::('BDD::Behave::DSL::&describe');
  };
  $impl(|args);
}

sub context(|args) is export {
  state $impl = do {
    require ::('BDD::Behave::DSL');
    ::('BDD::Behave::DSL::&context');
  };
  $impl(|args);
}

sub it(|args) is export {
  state $impl = do {
    require ::('BDD::Behave::DSL');
    ::('BDD::Behave::DSL::&it');
  };
  $impl(|args);
}
sub let(|args) is export {
  state $impl = do {
    require ::('BDD::Behave::DSL');
    ::('BDD::Behave::DSL::&let');
  };
  $impl(|args);
}
sub expect($given) is export {
  state $impl = do {
    require ::('BDD::Behave::DSL');
    ::('BDD::Behave::DSL::&expect');
  };
  $impl($given);
}
