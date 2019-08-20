
use lib 'lib';
use BDD::Behave::Actions;
use BDD::Behave::Grammar;
use BDD::Behave::Lets;
use Test;

plan 5;

my $m;

# <expect>
$m = Grammar.parse('expect(42)', :rule<expect>, :actions(Actions));
ok ($m<given> == 42), "\$m<given> == 42";

# <be>
$m = Grammar.parse('be(42)', :rule<be>, :actions(Actions));
ok ($m<expected> == 42), "\$m<expected> == 42";

# <expectation>
my $*LETS = Lets.new();
$m = Grammar.parse('expect(42).to.be(42);', :rule<expectation>, :actions(Actions));
ok ($m<expect><given> == 42), "\$m<expect><given> == 42";
ok ($m<be><expected> == 42), "\$m<be><expected> == 42";
ok ($m<expect><given> == $m<be><expected>), "\$m<expect><given> == \$m<be><expected>";

done-testing;
