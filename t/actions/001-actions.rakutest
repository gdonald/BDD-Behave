
use v6.d;
use lib 'lib';
use BDD::Behave::Actions;
use BDD::Behave::Grammar;
use BDD::Behave::Lets;
use Test;
use Test::Output;

plan 6;

my $m;

$m = Grammar.parse('expect(42)', :rule<expect>, :actions(Actions));
ok ($m<given> == 42);

$m = Grammar.parse('be(42)', :rule<be>, :actions(Actions));
ok ($m<expected> == 42);

my $*LETS = Lets.new();
my $out = "    \x[1B][36m⮑  \x[1B][0m\x[1B][32mSUCCESS\x[1B][0m\n";
output-is { $m = Grammar.parse('expect(42).to.be(42);', :rule<expectation>, :actions(Actions)) }, $out;
ok ($m<expect><given> == 42);
ok ($m<be><expected> == 42);
ok ($m<expect><given> == $m<be><expected>);
