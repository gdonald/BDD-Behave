
use v6.d;
use lib 'lib';
use BDD::Behave::Actions;
use BDD::Behave::Files;
use BDD::Behave::Grammar;
use BDD::Behave::Lets;
use Test;
use Test::Output;

plan 145;

my $m;
my $k;
my $out;

$out = "\n    \x[1B][36m⮑  \x[1B][0m\"a block\" \n\n    \x[1B][36m⮑  \x[1B][0m\"another block\" \n";
output-is { $m = Grammar.parse('use Foo; use Bar::Baz; describe -> "a block" {} describe -> "another block" {}', :rule<TOP>) }, $out;
ok $m<statements><use-statement>[0].Str eq 'use Foo;';
ok $m<statements><use-statement>[1].Str eq 'use Bar::Baz;';
ok $m<statements><use-statement>[0]<module-name>.Str eq 'Foo';
ok $m<statements><use-statement>[1]<module-name>.Str eq 'Bar::Baz';
ok $m<statements><describe-block>.Str eq "describe -> \"a block\" \{}  describe -> \"another block\" \{}";
ok $m<statements><describe-block>[0]<quoted-string>.Str eq "\"a block\" ";
ok $m<statements><describe-block>[1]<quoted-string>.Str eq "\"another block\" ";

output-is { $m = Grammar.parse("# comment\n", :rule<comment>) }, '';
ok $m.Str eq "# comment\n";
$m = Grammar.parse("#comment\n", :rule<comment>);
ok $m.Str eq "#comment\n";
$m = Grammar.parse("# comment\n\n", :rule<comment>);
ok $m.Str eq "# comment\n\n";
$m = Grammar.parse("## comment\n", :rule<comment>);
ok $m.Str eq "## comment\n";

$m = Grammar.parse("code # comment\n", :rule<comment>);
nok $m;
$m = Grammar.parse("code #comment\n", :rule<comment>);
nok $m;
$m = Grammar.parse("code # comment\n\n", :rule<comment>);
nok $m;
$m = Grammar.parse("code ## comment\n", :rule<comment>);
nok $m;

$m = Grammar.parse('"one two three"', :rule<quoted-string>);
ok $m.Str eq '"one two three"';
$m = Grammar.parse("'one two three'", :rule<quoted-string>);
ok $m.Str eq "'one two three'";

$m = Grammar.parse('"one"', :rule<double-quoted-string>);
ok $m.Str eq '"one"';
$m = Grammar.parse('"one two"', :rule<double-quoted-string>);
ok $m.Str eq '"one two"';
$m = Grammar.parse('"one two three"', :rule<double-quoted-string>);
ok $m.Str eq '"one two three"';

$m = Grammar.parse("'one'", :rule<single-quoted-string>);
ok $m.Str eq "'one'";
$m = Grammar.parse("'one two'", :rule<single-quoted-string>);
ok $m.Str eq "'one two'";
$m = Grammar.parse("'one two three'", :rule<single-quoted-string>);
ok $m.Str eq "'one two three'";

$m = Grammar.parse('one', :rule<phrase>);
ok $m.Str eq 'one';
$m = Grammar.parse('one two', :rule<phrase>);
ok $m.Str eq 'one two';
$m = Grammar.parse('one two three', :rule<phrase>);
ok $m.Str eq 'one two three';

$m = Grammar.parse('Foo', :rule<module-name>);
ok $m.Str eq 'Foo';
$m = Grammar.parse('Foo::Bar', :rule<module-name>);
ok $m.Str eq 'Foo::Bar';
$m = Grammar.parse('Foo::Bar::Baz', :rule<module-name>);
ok $m.Str eq 'Foo::Bar::Baz';

$m = Grammar.parse('use Foo;', :rule<use-statement>);
ok $m.Str eq 'use Foo;';
$m = Grammar.parse('use Foo::Bar;', :rule<use-statement>);
ok $m.Str eq 'use Foo::Bar;';
$m = Grammar.parse('use Foo::Bar::Baz;', :rule<use-statement>);
ok $m.Str eq 'use Foo::Bar::Baz;';

$m = Grammar.parse('be(1)', :rule<be>);
ok $m.Str eq 'be(1)';
$m = Grammar.parse('be( 1)', :rule<be>);
ok $m.Str eq 'be( 1)';
$m = Grammar.parse('be(1 )', :rule<be>);
ok $m.Str eq 'be(1 )';
$m = Grammar.parse('be( 1 )', :rule<be>);
ok $m.Str eq 'be( 1 )';

$m = Grammar.parse('be(', :rule<be>);
nok $m;
$m = Grammar.parse('bex', :rule<be>);
nok $m;
$m = Grammar.parse('xbe', :rule<be>);
nok $m;

$m = Grammar.parse('expect(1)', :rule<expect>);
ok $m.Str eq 'expect(1)';
$m = Grammar.parse('expect( 1)', :rule<expect>);
ok $m.Str eq 'expect( 1)';
$m = Grammar.parse('expect(1 )', :rule<expect>);
ok $m.Str eq 'expect(1 )';
$m = Grammar.parse('expect( 1 )', :rule<expect>);
ok $m.Str eq 'expect( 1 )';

$m = Grammar.parse('expect(', :rule<expect>);
nok $m;
$m = Grammar.parse('expectx', :rule<expect>);
nok $m;
$m = Grammar.parse('xexpect', :rule<expect>);
nok $m;

$out = "    \x[1B][36m⮑  \x[1B][0m\x[1B][32mSUCCESS\x[1B][0m\n";
output-is { $m = Grammar.parse('expect(1).to.be(1);', :rule<expectation>) }, $out;
ok $m.Str eq 'expect(1).to.be(1);';
output-is { $m = Grammar.parse('expect( 1).to.be( 1);', :rule<expectation>) }, $out;
ok $m.Str eq 'expect( 1).to.be( 1);';
output-is { $m = Grammar.parse('expect(1 ).to.be(1 );', :rule<expectation>) }, $out;
ok $m.Str eq 'expect(1 ).to.be(1 );';
output-is { $m = Grammar.parse('expect( 1 ).to.be( 1 );', :rule<expectation>) }, $out;
ok $m.Str eq 'expect( 1 ).to.be( 1 );';

$out = "    \x[1B][36m⮑  \x[1B][0m\"1 is 1\" \n        \x[1B][36m⮑  \x[1B][0m\x[1B][32mSUCCESS\x[1B][0m\n";
output-is { $m = Grammar.parse('it -> "1 is 1" { expect(1).to.be(1); }', :rule<it-block>) }, $out;
ok $m.Str eq 'it -> "1 is 1" { expect(1).to.be(1); }';
output-is { $m = Grammar.parse('it-> "1 is 1" { expect(1).to.be(1); }', :rule<it-block>) }, $out;
ok $m.Str eq 'it-> "1 is 1" { expect(1).to.be(1); }';
output-is { $m = Grammar.parse('it ->"1 is 1" { expect(1).to.be(1); }', :rule<it-block>) }, $out;
ok $m.Str eq 'it ->"1 is 1" { expect(1).to.be(1); }';

$out = "    \x[1B][36m⮑  \x[1B][0m\"1 is 1\"\n        \x[1B][36m⮑  \x[1B][0m\x[1B][32mSUCCESS\x[1B][0m\n";
output-is { $m = Grammar.parse('it -> "1 is 1"{ expect(1).to.be(1); }', :rule<it-block>) }, $out;
ok $m.Str eq 'it -> "1 is 1"{ expect(1).to.be(1); }';

$out = "    \x[1B][36m⮑  \x[1B][0m\"1 is 1\" \n        \x[1B][36m⮑  \x[1B][0m\x[1B][32mSUCCESS\x[1B][0m\n";
output-is { $m = Grammar.parse('it -> "1 is 1" {expect(1).to.be(1); }', :rule<it-block>) }, $out;
ok $m.Str eq 'it -> "1 is 1" {expect(1).to.be(1); }';
output-is { $m = Grammar.parse('it -> "1 is 1" { expect(1).to.be(1);}', :rule<it-block>) }, $out;
ok $m.Str eq 'it -> "1 is 1" { expect(1).to.be(1);}';

$out = "    \x[1B][36m⮑  \x[1B][0m\"1 is 1\" \n";
output-is { $m = Grammar.parse('it -> "1 is 1" {}', :rule<it-block>) }, $out;
ok $m.Str eq 'it -> "1 is 1" {}';

$out = "    \x[1B][36m⮑  \x[1B][0m\"1 is 1\" \n        \x[1B][36m⮑  \x[1B][0m\x[1B][32mSUCCESS\x[1B][0m\n        \x[1B][36m⮑  \x[1B][0m\x[1B][32mSUCCESS\x[1B][0m\n";
output-is { $m = Grammar.parse('it -> "1 is 1" { expect(1).to.be(1); expect(2).to.be(2); }', :rule<it-block>) }, $out;
ok $m.Str eq 'it -> "1 is 1" { expect(1).to.be(1); expect(2).to.be(2); }';
output-is { $m = Grammar.parse('it -> "1 is 1" { expect(1).to.be(1);expect(2).to.be(2); }', :rule<it-block>) }, $out;
ok $m.Str eq 'it -> "1 is 1" { expect(1).to.be(1);expect(2).to.be(2); }';

$out = "\n    \x[1B][36m⮑  \x[1B][0m\"contains an it block\" \n        \x[1B][36m⮑  \x[1B][0m\"1 is 1\" \n            \x[1B][36m⮑  \x[1B][0m\x[1B][32mSUCCESS\x[1B][0m\n";
output-is { $m = Grammar.parse('context -> "contains an it block" { it -> "1 is 1" { expect(1).to.be(1); } }', :rule<context-block>) }, $out;
ok $m.Str eq 'context -> "contains an it block" { it -> "1 is 1" { expect(1).to.be(1); } }';
output-is { $m = Grammar.parse('context-> "contains an it block" { it -> "1 is 1" { expect(1).to.be(1); } }', :rule<context-block>) }, $out;
ok $m.Str eq 'context-> "contains an it block" { it -> "1 is 1" { expect(1).to.be(1); } }';
output-is { $m = Grammar.parse('context ->"contains an it block" { it -> "1 is 1" { expect(1).to.be(1); } }', :rule<context-block>) }, $out;
ok $m.Str eq 'context ->"contains an it block" { it -> "1 is 1" { expect(1).to.be(1); } }';

$out = "\n    \x[1B][36m⮑  \x[1B][0m\"contains an it block\"\n        \x[1B][36m⮑  \x[1B][0m\"1 is 1\" \n            \x[1B][36m⮑  \x[1B][0m\x[1B][32mSUCCESS\x[1B][0m\n";
output-is { $m = Grammar.parse('context -> "contains an it block"{ it -> "1 is 1" { expect(1).to.be(1); } }', :rule<context-block>) }, $out;
ok $m.Str eq 'context -> "contains an it block"{ it -> "1 is 1" { expect(1).to.be(1); } }';

$out = "\n    \x[1B][36m⮑  \x[1B][0m\"contains an it block\" \n        \x[1B][36m⮑  \x[1B][0m\"1 is 1\" \n            \x[1B][36m⮑  \x[1B][0m\x[1B][32mSUCCESS\x[1B][0m\n";
output-is { $m = Grammar.parse('context -> "contains an it block" {it -> "1 is 1" { expect(1).to.be(1); } }', :rule<context-block>) }, $out;
ok $m.Str eq 'context -> "contains an it block" {it -> "1 is 1" { expect(1).to.be(1); } }';
output-is { $m = Grammar.parse('context -> "contains an it block" { it -> "1 is 1" { expect(1).to.be(1); }}', :rule<context-block>) }, $out;
ok $m.Str eq 'context -> "contains an it block" { it -> "1 is 1" { expect(1).to.be(1); }}';

$out = "\n    \x[1B][36m⮑  \x[1B][0m\"a empty block\" \n";
output-is { $m = Grammar.parse('describe -> "a empty block" {}', :rule<describe-block>) }, $out;
ok $m.Str eq 'describe -> "a empty block" {}';

$out = "\n    \x[1B][36m⮑  \x[1B][0m\"contains a context block\" \n\n        \x[1B][36m⮑  \x[1B][0m\"contains an it block\" \n            \x[1B][36m⮑  \x[1B][0m\"1 is 1\" \n                \x[1B][36m⮑  \x[1B][0m\x[1B][32mSUCCESS\x[1B][0m\n";
output-is { $m = Grammar.parse('describe -> "contains a context block" { context -> "contains an it block" { it -> "1 is 1" { expect(1).to.be(1); } } }', :rule<describe-block>) }, $out;
ok $m.Str eq 'describe -> "contains a context block" { context -> "contains an it block" { it -> "1 is 1" { expect(1).to.be(1); } } }';
output-is { $m = Grammar.parse('describe-> "contains a context block" { context -> "contains an it block" { it -> "1 is 1" { expect(1).to.be(1); } } }', :rule<describe-block>) }, $out;
ok $m.Str eq 'describe-> "contains a context block" { context -> "contains an it block" { it -> "1 is 1" { expect(1).to.be(1); } } }';
output-is { $m = Grammar.parse('describe ->"contains a context block" { context -> "contains an it block" { it -> "1 is 1" { expect(1).to.be(1); } } }', :rule<describe-block>) }, $out;
ok $m.Str eq 'describe ->"contains a context block" { context -> "contains an it block" { it -> "1 is 1" { expect(1).to.be(1); } } }';

$out = "\n    \x[1B][36m⮑  \x[1B][0m\"contains a context block\"\n\n        \x[1B][36m⮑  \x[1B][0m\"contains an it block\" \n            \x[1B][36m⮑  \x[1B][0m\"1 is 1\" \n                \x[1B][36m⮑  \x[1B][0m\x[1B][32mSUCCESS\x[1B][0m\n";
output-is { $m = Grammar.parse('describe -> "contains a context block"{ context -> "contains an it block" { it -> "1 is 1" { expect(1).to.be(1); } } }', :rule<describe-block>) }, $out;
ok $m.Str eq 'describe -> "contains a context block"{ context -> "contains an it block" { it -> "1 is 1" { expect(1).to.be(1); } } }';

$out = "\n    \x[1B][36m⮑  \x[1B][0m\"contains a context block\" \n\n        \x[1B][36m⮑  \x[1B][0m\"contains an it block\" \n            \x[1B][36m⮑  \x[1B][0m\"1 is 1\" \n                \x[1B][36m⮑  \x[1B][0m\x[1B][32mSUCCESS\x[1B][0m\n";
output-is { $m = Grammar.parse('describe -> "contains a context block" {context -> "contains an it block" { it -> "1 is 1" { expect(1).to.be(1); } } }', :rule<describe-block>) }, $out;
ok $m.Str eq 'describe -> "contains a context block" {context -> "contains an it block" { it -> "1 is 1" { expect(1).to.be(1); } } }';
output-is { $m = Grammar.parse('describe -> "contains a context block" { context -> "contains an it block" { it -> "1 is 1" { expect(1).to.be(1); } }}', :rule<describe-block>) }, $out;
ok $m.Str eq 'describe -> "contains a context block" { context -> "contains an it block" { it -> "1 is 1" { expect(1).to.be(1); } }}';

$out = "\n    \x[1B][36m⮑  \x[1B][0m\"contains two context blocks\" \n\n        \x[1B][36m⮑  \x[1B][0m\"contains an it block\" \n            \x[1B][36m⮑  \x[1B][0m\"1 is 1\" \n                \x[1B][36m⮑  \x[1B][0m\x[1B][32mSUCCESS\x[1B][0m\n\n        \x[1B][36m⮑  \x[1B][0m\"contains an it block\" \n            \x[1B][36m⮑  \x[1B][0m\"1 is 1\" \n                \x[1B][36m⮑  \x[1B][0m\x[1B][32mSUCCESS\x[1B][0m\n";
output-is { $m = Grammar.parse('describe -> "contains two context blocks" { context -> "contains an it block" { it -> "1 is 1" { expect(1).to.be(1); } } context -> "contains an it block" { it -> "1 is 1" { expect(1).to.be(1); } } }', :rule<describe-block>) }, $out;
ok $m.Str eq 'describe -> "contains two context blocks" { context -> "contains an it block" { it -> "1 is 1" { expect(1).to.be(1); } } context -> "contains an it block" { it -> "1 is 1" { expect(1).to.be(1); } } }';

$out = "\n    \x[1B][36m⮑  \x[1B][0m\"contains an it block\" \n        \x[1B][36m⮑  \x[1B][0m\"1 is 1\" \n            \x[1B][36m⮑  \x[1B][0m\x[1B][32mSUCCESS\x[1B][0m\n";
output-is { $m = Grammar.parse('describe -> "contains an it block" { it -> "1 is 1" { expect(1).to.be(1); } }', :rule<describe-block>) }, $out;
ok $m.Str eq 'describe -> "contains an it block" { it -> "1 is 1" { expect(1).to.be(1); } }';

$out = "\n    \x[1B][36m⮑  \x[1B][0m\"contains two it blocks\" \n        \x[1B][36m⮑  \x[1B][0m\"1 is 1\" \n            \x[1B][36m⮑  \x[1B][0m\x[1B][32mSUCCESS\x[1B][0m\n        \x[1B][36m⮑  \x[1B][0m\"1 is 1\" \n            \x[1B][36m⮑  \x[1B][0m\x[1B][32mSUCCESS\x[1B][0m\n";
output-is { $m = Grammar.parse('describe -> "contains two it blocks" { it -> "1 is 1" { expect(1).to.be(1); } it -> "1 is 1" { expect(1).to.be(1); } }', :rule<describe-block>) }, $out;
ok $m.Str eq 'describe -> "contains two it blocks" { it -> "1 is 1" { expect(1).to.be(1); } it -> "1 is 1" { expect(1).to.be(1); } }';

$out = "\n    \x[1B][36m⮑  \x[1B][0m\"contains a describe block\" \n\n        \x[1B][36m⮑  \x[1B][0m\"contains a context block\" \n\n            \x[1B][36m⮑  \x[1B][0m\"contains an it block\" \n                \x[1B][36m⮑  \x[1B][0m\"1 is 1\" \n                    \x[1B][36m⮑  \x[1B][0m\x[1B][32mSUCCESS\x[1B][0m\n";
output-is { $m = Grammar.parse('describe -> "contains a describe block" { describe -> "contains a context block" { context -> "contains an it block" { it -> "1 is 1" { expect(1).to.be(1); } } } }', :rule<describe-block>) }, $out;
ok $m.Str eq 'describe -> "contains a describe block" { describe -> "contains a context block" { context -> "contains an it block" { it -> "1 is 1" { expect(1).to.be(1); } } } }';

$out = "\n    \x[1B][36m⮑  \x[1B][0m\"contains two describe blocks\" \n\n        \x[1B][36m⮑  \x[1B][0m\"contains a context block\" \n\n            \x[1B][36m⮑  \x[1B][0m\"contains an it block\" \n                \x[1B][36m⮑  \x[1B][0m\"1 is 1\" \n                    \x[1B][36m⮑  \x[1B][0m\x[1B][32mSUCCESS\x[1B][0m\n\n        \x[1B][36m⮑  \x[1B][0m\"contains a context block\" \n\n            \x[1B][36m⮑  \x[1B][0m\"contains an it block\" \n                \x[1B][36m⮑  \x[1B][0m\"1 is 1\" \n                    \x[1B][36m⮑  \x[1B][0m\x[1B][32mSUCCESS\x[1B][0m\n";
output-is { $m = Grammar.parse('describe -> "contains two describe blocks" { describe -> "contains a context block" { context -> "contains an it block" { it -> "1 is 1" { expect(1).to.be(1); } } } describe -> "contains a context block" { context -> "contains an it block" { it -> "1 is 1" { expect(1).to.be(1); } } } }', :rule<describe-block>) }, $out;
ok $m.Str eq 'describe -> "contains two describe blocks" { describe -> "contains a context block" { context -> "contains an it block" { it -> "1 is 1" { expect(1).to.be(1); } } } describe -> "contains a context block" { context -> "contains an it block" { it -> "1 is 1" { expect(1).to.be(1); } } } }';

$out = "\n    \x[1B][36m⮑  \x[1B][0m\"a block\" \n";
output-is { $m = Grammar.parse('use Foo; describe -> "a block" {}', :rule<statements>) }, $out;
ok $m.Str eq 'use Foo; describe -> "a block" {}';
output-is { $m = Grammar.parse('describe -> "a block" {}', :rule<statements>) }, $out;
ok $m.Str eq 'describe -> "a block" {}';

$m = Grammar.parse('use Foo;', :rule<statements>);
ok $m.Str eq 'use Foo;';

$m = Grammar.parse('let(:foo)', :rule<let>);
ok $m eq 'let(:foo)';
ok $m<symbol> eq ':foo';

$m = Grammar.parse('let(:foo) => { 42 };', :rule<let-statement>, :actions(Actions));
ok ($m<let><symbol> eq ':foo');
ok ($m<block-content> == 42);

$m = Grammar.parse('let(:foo) => { Foo.new };', :rule<let-statement>, :actions(Actions));
ok ($m<let><symbol> eq ':foo');
ok ($m<block-content> eq 'Foo.new');

$m = Grammar.parse('let(:foo) => { Foo.new(17) };', :rule<let-statement>, :actions(Actions));
ok ($m<let><symbol> eq ':foo');
ok ($m<block-content> eq 'Foo.new(17)');

$m = Grammar.parse('let(:foo) => { 42 };', :rule<let-statement>);
ok $m eq 'let(:foo) => { 42 };';
$m = Grammar.parse('let(:foo) => {42};', :rule<let-statement>);
ok $m eq 'let(:foo) => {42};';
$m = Grammar.parse('let(:foo)=>{ 42 };', :rule<let-statement>);
ok $m eq 'let(:foo)=>{ 42 };';

$m = Grammar.parse('let(:foo) => { "42" };', :rule<let-statement>);
ok $m eq 'let(:foo) => { "42" };';
$m = Grammar.parse('let(:foo) => {"42"};', :rule<let-statement>);
ok $m eq 'let(:foo) => {"42"};';
$m = Grammar.parse('let(:foo)=>{ "42" };', :rule<let-statement>);
ok $m eq 'let(:foo)=>{ "42" };';

$m = Grammar.parse("let(:foo) => \{ '42' \};", :rule<let-statement>);
ok $m eq "let(:foo) => \{ '42' \};";
$m = Grammar.parse("let(:foo) => \{'42'\};", :rule<let-statement>);
ok $m eq "let(:foo) => \{'42'\};";
$m = Grammar.parse("let(:foo)=>\{ '42' \};", :rule<let-statement>);
ok $m eq "let(:foo)=>\{ '42' \};";

$k = q:to/END/;
class Foo {
  has $!bar;
  has $!baz;

  submethod BUILD(:$!bar) {
    $!baz = 42;
  }
}

END

$m = Grammar.parse($k, :rule<klass-definition>);
ok $m.Str eq "class Foo \{\n  has \$!bar;\n  has \$!baz;\n\n  submethod BUILD(:\$!bar) \{\n    \$!baz = 42;\n  }\n}\n\n";
$m = Grammar.parse($k, :rule<statements>);
ok $m.Str eq "class Foo \{\n  has \$!bar;\n  has \$!baz;\n\n  submethod BUILD(:\$!bar) \{\n    \$!baz = 42;\n  }\n}\n\n";
$m = Grammar.parse($k, :rule<TOP>);
ok $m.Str eq "class Foo \{\n  has \$!bar;\n  has \$!baz;\n\n  submethod BUILD(:\$!bar) \{\n    \$!baz = 42;\n  }\n}\n\n";

$k = q:to/END/;

use BDD::Behave;

class Foo {
  has $!bar;
  has $!baz;

  submethod BUILD(:$!bar) {
    $!baz = 42;
  }
}

let(:foo) => { Foo.new(17) };

describe -> 'Foo' {
  it -> '.bar' {
    expect(:foo).to.be(17);
  }
}

END

Files.current = 'test';
$out = "\n    \x[1B][36m⮑  \x[1B][0m'Foo' \n        \x[1B][36m⮑  \x[1B][0m'.bar' \n            \x[1B][36m⮑  \x[1B][0m\x[1B][31mFAILURE\x[1B][0m\n";
output-is { $m = Grammar.parse($k, :rule<TOP>) }, $out;
ok $m<statements><use-statement>.Str eq "use BDD::Behave;";
ok $m<statements><klass-definition>.Str eq "class Foo \{\n  has \$!bar;\n  has \$!baz;\n\n  submethod BUILD(:\$!bar) \{\n    \$!baz = 42;\n  }\n}\n\n";
ok $m<statements><let-statement>.Str eq "let(:foo) => \{ Foo.new(17) };\n\n";

output-is { $m = Grammar.parse($k, :rule<statements>) }, $out;
ok $m<use-statement>.Str eq "use BDD::Behave;";
ok $m<klass-definition>.Str eq "class Foo \{\n  has \$!bar;\n  has \$!baz;\n\n  submethod BUILD(:\$!bar) \{\n    \$!baz = 42;\n  }\n}\n\n";
ok $m<let-statement>.Str eq "let(:foo) => \{ Foo.new(17) };\n\n";

$k = "class Foo \{ has \$!bar; has \$!baz; submethod BUILD(:\$!bar) \{ \$!baz = 42; } }\n";
$out = '';
output-is { $m = Grammar.parse($k, :rule<klass-definition>) }, $out;
ok $m.Str eq "class Foo \{ has \$!bar; has \$!baz; submethod BUILD(:\$!bar) \{ \$!baz = 42; } }\n";
