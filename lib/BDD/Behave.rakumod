
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

sub context is export {}
sub describe is export {}
sub let is export {}
sub it is export {}
sub expect is export {}
