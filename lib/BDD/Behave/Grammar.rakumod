
use MONKEY-SEE-NO-EVAL;

# use Grammar::Tracer;
# use Grammar::ErrorReporting;

use BDD::Behave::Expectation;
use BDD::Behave::Indent;
use BDD::Behave::Klasses;
use BDD::Behave::Lets;

grammar Grammar is export {

  token single-quote { \' }
  token double-quote { \" }
  token word { \w+ }
  token number { \d+ }
  token dot-method { \.\w+ }
  token symbol { \:\w+ }
  token block-content { <[\.\:\"\'\d\w\(\)]>+ }
  token given { <[$\.\:\"\'\d\w]>+ }
  token expected { <[\.\:\"\'\d\w]>+ }
  
  token comment-string { '#'\N*\n }
  rule comment-line { ^^ <comment-string> $$ }
  
  token var-name { <[\$\!\.]>+\w+ }
  # token data-begin { ^^ <[#]> <.ws> DATA\-BEGIN $$ }
  # rule data-content { .+ <?before <[#]> DATA\-END> }
  # token data-end { ^^ <[#]> <.ws> DATA\-END $$ }

  rule expect { 'expect(' <given> ')' }
  rule be { 'be(' <expected> ')' }
  rule let { 'let(' <symbol> ')' }

  rule phrase {
    [
      | <word>
      | <dot-method>
    ]*
  }

  rule module-name { <word> [\:\: <word>]* }
  rule klass-name { <word> [\:\: <word>]* }

  rule single-quoted-string { <single-quote><phrase><single-quote> }
  rule double-quoted-string { <double-quote><phrase><double-quote> }
  rule quoted-string { [ <single-quoted-string> | <double-quoted-string> ] }

  rule use-statement { use <module-name>\; }
  rule has-statement { has <var-name>\; }
  rule var-assignment { <var-name> \= <number>\; }

  # rule data {
  #   <data-begin> <data-content> <data-end>
  #   {
  #     EVAL $/.<data-content>;
  #   }
  # }

  rule submethod {
    submethod BUILD\(\:<var-name>\) \{
      [
        <var-assignment>
      ]*
    \}
  }

  rule klass-definition {
    class <klass-name> \{
      [
        | <has-statement>
        | <submethod>
      ]*
    \}
    {
      my $name = $/.<klass-name>.Str.trim();
      my $def = $/.Str.trim();
      Klasses.put(:$name, :$def);
    }
  }

  rule let-statement {
    <let> \=\> \{ <block-content> \}\;
    {
      my $block = { $<block-content> };
      Lets.put(:name($<let><symbol>.Str), :$block)
    }
  }

  rule expectation-not {
    <expect>\.to\.not\.<be>\; <comment-string>?
    {
      my $line = self.line-number;
      my $raw = $<expect><given>.Str;
      my $e = Expectation.new(:$raw, :$line);
      $e.to().not().be($<be><expected>.Str);
    }
  }

  rule expectation {
    <expect>\.to\.<be>\; <comment-string>?
    {
      my $line = self.line-number;
      my $raw = $<expect><given>.Str;
      my $e = Expectation.new(:$raw, :$line);
      $e.to().be($<be><expected>.Str);
    }
  }

  rule it-block {
    it \-\> <quoted-string> \{
      { Indent.increase; }
      { say Indent.get ~ $<quoted-string>; }
      { Lets.push-scope() }
      [
        | <comment-line>
        | <let-statement>
        | <expectation>
        | <expectation-not>
      ]*
      { Lets.pop-scope() }
      { Indent.decrease; }
    \}
  }

  rule context-block {
    context \-\> <quoted-string> \{
      { Indent.increase; }
      { say "\n" ~ Indent.get ~ $<quoted-string>; }
      { Lets.push-scope() }
      [
        | <comment-line>
        | <let-statement>
        | <it-block>
      ]*
      { Lets.pop-scope() }
      { Indent.decrease; }
    \}
  }

  rule describe-block {
    describe \-\> <quoted-string> \{
      { Indent.increase; }
      { say "\n" ~ Indent.get ~ $<quoted-string>; }
      { Lets.push-scope() }
      [
        | <comment-line>
        | <let-statement>
        | <describe-block>
        | <context-block>
        | <it-block>
      ]*
      { Lets.pop-scope() }
      { Indent.decrease; }
    \}
  }

  rule statements {
    [
      | <comment-line>
      | <klass-definition>
      | <use-statement>
      | <let-statement>
      | <describe-block>
    ]*
  }

  rule TOP {
    <statements>
  }

  method line-number {
    my $parsed = self.target.substr(0, self.pos);
    $parsed.lines.elems + 1;
  }
}
