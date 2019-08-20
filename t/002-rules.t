
use lib 'lib';
use BDD::Behave::Actions;
use BDD::Behave::Grammar;
use BDD::Behave::Lets;
use Test;

plan 91;

my @strings;
my $m;

# <quoted-string>
@strings =
  '"one two three"',
  "'one two three'";

for @strings -> $str {
  ok Grammar.parse($str, :rule<quoted-string>), "parses $str as <quoted-string>";
}

# <double-quoted-string>
@strings =
  '"one"',
  '"one two"',
  '"one two three"';

for @strings -> $str {
  ok Grammar.parse($str, :rule<double-quoted-string>), "parses $str as <double-quoted-string>";
}

# <single-quoted-string>
@strings =
  "'one'",
  "'one two'",
  "'one two three'";

for @strings -> $str {
  ok Grammar.parse($str, :rule<single-quoted-string>), "parses $str as <single-quoted-string>";
}

# <phrase>
@strings =
  'one',
  'one two',
  'one two three';

for @strings -> $str {
  ok Grammar.parse($str, :rule<phrase>), "parses $str as <phrase>";
}

# <module-name>
@strings =
  'Foo',
  'Foo::Bar',
  'Foo::Bar::Baz';

for @strings -> $str {
  ok Grammar.parse($str, :rule<module-name>), "parses $str as <module-name>";
}

# <use-statement>
@strings =
  'use Foo;',
  'use Foo::Bar;',
  'use Foo::Bar::Baz;';

for @strings -> $str {
  ok Grammar.parse($str, :rule<use-statement>), "parses $str as <use-statement>";
}

# <be>
@strings =
  'be(1)',
  'be( 1)',
  'be(1 )',
  'be( 1 )';

for @strings -> $str {
  ok Grammar.parse($str, :rule<be>), "parses $str as <be>";
}

@strings =
  'be(',
  'bex',
  'xbe';

for @strings -> $str {
  nok Grammar.parse($str, :rule<be>), "does not parse $str as <be>";
}

# <expect>
@strings =
  'expect(1)',
  'expect( 1)',
  'expect(1 )',
  'expect( 1 )';

for @strings -> $str {
  ok Grammar.parse($str, :rule<expect>), "parses $str as <expect>";
}

@strings =
  'expect(',
  'expectx',
  'xexpect';

for @strings -> $str {
  nok Grammar.parse($str, :rule<expect>), "does not parse $str as <expect>";
}

# <expectation>
@strings = 'expect(1).to.be(1);';

for @strings -> $str {
  ok Grammar.parse($str, :rule<expectation>), "parses $str as <expectation>";
}

# <it-block>
@strings =
  'it -> "1 is 1" { expect(1).to.be(1); }',
  'it-> "1 is 1" { expect(1).to.be(1); }',
  'it ->"1 is 1" { expect(1).to.be(1); }',
  'it -> "1 is 1"{ expect(1).to.be(1); }',
  'it -> "1 is 1" {expect(1).to.be(1); }',
  'it -> "1 is 1" { expect(1).to.be(1);}',
  'it -> "1 is 1" {}',
  'it -> "1 is 1" { expect(1).to.be(1); expect(2).to.be(2); }',
  'it -> "1 is 1" { expect(1).to.be(1);expect(2).to.be(2); }';

for @strings -> $str {
  ok Grammar.parse($str, :rule<it-block>), "parses $str as <it-block>";
}

# <context-block>
@strings =
  'context -> "contains an it block" { it -> "1 is 1" { expect(1).to.be(1); } }',
  'context-> "contains an it block" { it -> "1 is 1" { expect(1).to.be(1); } }',
  'context ->"contains an it block" { it -> "1 is 1" { expect(1).to.be(1); } }',
  'context -> "contains an it block"{ it -> "1 is 1" { expect(1).to.be(1); } }',
  'context -> "contains an it block" {it -> "1 is 1" { expect(1).to.be(1); } }',
  'context -> "contains an it block" { it -> "1 is 1" { expect(1).to.be(1); }}';

for @strings -> $str {
  ok Grammar.parse($str, :rule<context-block>), "parses $str as <context-block>";
}

# <describe-block>
@strings =
  'describe -> "a empty block" {}',
  'describe -> "contains a context block" { context -> "contains an it block" { it -> "1 is 1" { expect(1).to.be(1); } } }',
  'describe-> "contains a context block" { context -> "contains an it block" { it -> "1 is 1" { expect(1).to.be(1); } } }',
  'describe ->"contains a context block" { context -> "contains an it block" { it -> "1 is 1" { expect(1).to.be(1); } } }',
  'describe -> "contains a context block"{ context -> "contains an it block" { it -> "1 is 1" { expect(1).to.be(1); } } }',
  'describe -> "contains a context block" {context -> "contains an it block" { it -> "1 is 1" { expect(1).to.be(1); } } }',
  'describe -> "contains a context block" { context -> "contains an it block" { it -> "1 is 1" { expect(1).to.be(1); } }}',
  'describe -> "contains two context blocks" { context -> "contains an it block" { it -> "1 is 1" { expect(1).to.be(1); } } context -> "contains an it block" { it -> "1 is 1" { expect(1).to.be(1); } } }',
  'describe -> "contains an it block" { it -> "1 is 1" { expect(1).to.be(1); } }',
  'describe -> "contains two it blocks" { it -> "1 is 1" { expect(1).to.be(1); } it -> "1 is 1" { expect(1).to.be(1); } }',
  'describe -> "contains a describe block" { describe -> "contains a context block" { context -> "contains an it block" { it -> "1 is 1" { expect(1).to.be(1); } } } }',
  'describe -> "contains two describe blocks" { describe -> "contains a context block" { context -> "contains an it block" { it -> "1 is 1" { expect(1).to.be(1); } } } describe -> "contains a context block" { context -> "contains an it block" { it -> "1 is 1" { expect(1).to.be(1); } } } }';

for @strings -> $str {
  ok Grammar.parse($str, :rule<describe-block>), "parses $str as <describe-block>";
}

# <statements>
@strings =
  'use Foo; describe -> "a block" {}',
  'describe -> "a block" {}',
  'use Foo;';

for @strings -> $str {
  ok Grammar.parse($str, :rule<statements>), "parses $str as <statements>";
}

# <let-statement>
@strings =
        'let(:foo) => { 42 };',
        'let(:foo) => {42};',
        'let(:foo)=>{ 42 };';

for @strings -> $str {
  ok Grammar.parse($str, :rule<let-statement>), "parses $str as <let-statement>";
  ok Lets.get(':foo') == 42, ":foo is 42";
}

@strings =
        'let(:foo) => { "42" };',
        'let(:foo) => {"42"};',
        'let(:foo)=>{ "42" };';

for @strings -> $str {
  ok Grammar.parse($str, :rule<let-statement>), "parses $str as <let-statement>";
  ok Lets.get(':foo') eq '"42"', ':foo is "42"';
}

@strings =
        "let(:foo) => \{ '42' \};",
        "let(:foo) => \{'42'\};",
        "let(:foo)=>\{ '42' \};";

for @strings -> $str {
  ok Grammar.parse($str, :rule<let-statement>), "parses $str as <let-statement>";
  ok Lets.get(':foo') eq "'42'", ":foo is '42'";
}

$m = Grammar.parse('let(:foo) => { 42 };', :rule<let-statement>, :actions(Actions));
ok ($m<symbol> eq ':foo'), "\$m<symbol> == ':foo'";
ok ($m<block-content> == 42), "\$m<block-content> == 42";

# <TOP>
@strings = 'use Foo; use Bar::Baz; describe -> "a block" {} describe -> "a block" {}', ;

for @strings -> $str {
  ok Grammar.parse($str, :rule<TOP>), "parses $str as <TOP>";
}

# <comment>
@strings =
  "# comment\n",
  "#comment\n",
  "# comment\n\n",
  "## comment\n";

for @strings -> $str {
  ok Grammar.parse($str, :rule<comment>), "parses $str as <comment>";
}

@strings =
  "code # comment\n",
  "code #comment\n",
  "code # comment\n\n",
  "code ## comment\n";

for @strings -> $str {
  nok Grammar.parse($str, :rule<comment>), "does not parse $str as <comment>";
}

done-testing;
