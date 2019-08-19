
unit grammar BDD::Behave::Grammar;

use BDD::Behave::Expectation;
use BDD::Behave::Indent;
use BDD::Behave::Lets;

grammar Grammar is export {

  token single-quote { \' }
  token double-quote { \" }
  token word { \w+ }
  token symbol { \:\w+ }
  token block-content { <[\:\"\'\d\w]>+ }
  token comment { [ [ <[#]> \N* ]? \n ]+ }

  rule given { <block-content> }
  rule expected { <block-content> }

  rule expect { 'expect(' <given> ')' }
  rule be { 'be(' <expected> ')' }

  rule phrase { <word> [<.ws> <word>]* }
  rule module-name { <word> [\:\: <word>]* }

  rule single-quoted-string { <single-quote><phrase><single-quote> }
  rule double-quoted-string { <double-quote><phrase><double-quote> }
  rule quoted-string { [ <single-quoted-string> | <double-quoted-string> ] }

  rule use-statement { use <module-name>\; }

  rule let-statement {
    let\(<symbol>\) \=\> \{ <block-content> \}\;
    {
      my $block = { $<block-content> };
      $*LETS.put(:name($<symbol>.Str), :$block)
    }
  }

  rule expectation-not {
    <expect>\.to\.not\.<be>\; <comment>?
    {
      my $line = self.line-number;
      my $e = Expectation.new(:given($<expect><given>), :lets($*LETS), :$line);
      $e.to().not().be($<be><expected>);
    }
  }

  rule expectation {
    <expect>\.to\.<be>\; <comment>?
    {
      my $line = self.line-number;
      my $e = Expectation.new(:given($<expect><given>), :lets($*LETS), :$line);
      $e.to().be($<be><expected>);
    }
  }

  rule it-block {
    it \-\> <quoted-string> \{
      { Indent.increase; }
      { say Indent.get ~ $<quoted-string>; }
      { $*LETS.push-scope() }
      [
        | <comment>
        | <let-statement>
        | <expectation>
        | <expectation-not>
      ]*
      { $*LETS.pop-scope() }
      { Indent.decrease; }
    \}
  }

  rule context-block {
    context \-\> <quoted-string> \{
      { Indent.increase; }
      { say "\n" ~ Indent.get ~ $<quoted-string>; }
      { $*LETS.push-scope() }
      [
        | <comment>
        | <let-statement>
        | <it-block>
      ]*
      { $*LETS.pop-scope() }
      { Indent.decrease; }
    \}
  }

  rule describe-block {
    describe \-\> <quoted-string> \{
      { Indent.increase; }
      { say "\n" ~ Indent.get ~ $<quoted-string>; }
      { $*LETS.push-scope() }
      [
        | <comment>
        | <let-statement>
        | <describe-block>
        | <context-block>
        | <it-block>
      ]*
      { $*LETS.pop-scope() }
      { Indent.decrease; }
    \}
  }

  rule statements {
    [
      | <comment>
      | <use-statement>
      | <let-statement>
      | <describe-block>
    ]*
  }

  rule TOP {
    :my $*LETS = Lets.new();
    <statements>
  }

  method line-number {
    my $parsed = self.target.substr(0, self.pos);
    ($parsed.lines.elems + 1).Str;
  }
}
