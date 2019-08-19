
use lib 'lib';
use BDD::Behave::Grammar;
use Test;

my $m;

# <double-quote>
ok Grammar.parse('"', :rule<double-quote>), 'parses `"` as <double-quote>';
nok Grammar.parse("'", :rule<double-quote>), "does not parse `'` as <double-quote>";

# <single-quote>
ok Grammar.parse("'", :rule<single-quote>), "parses `'` as <single-quote>";
nok Grammar.parse('"', :rule<single-quote>), 'does not parse `"` as <single-quote>';

# <word>
ok Grammar.parse('word', :rule<word>), 'parses "word" as <word>';
nok Grammar.parse('word x', :rule<word>), 'does not parse "word x" as <word>';
nok Grammar.parse('x word', :rule<word>), 'does not parse "x word" as <word>';

# <symbol>
ok Grammar.parse(':foo', :rule<symbol>), 'parses ":foo" as <symbol>';
nok Grammar.parse(':foo x', :rule<symbol>), 'does not parse ":foo x" as <symbol>';
nok Grammar.parse('x :foo', :rule<symbol>), 'does not parse "x :foo" as <symbol>';

# <block-content>
ok Grammar.parse('42', :rule<block-content>), 'parses "42" as <block-content>';
ok Grammar.parse(':foo', :rule<block-content>), 'parses ":foo" as <block-content>';
ok Grammar.parse('bar', :rule<block-content>), 'parses "bar" as <block-content>';

done-testing;