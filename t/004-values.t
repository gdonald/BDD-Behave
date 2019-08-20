
use lib 'lib';
use BDD::Behave::Grammar;
use BDD::Behave::Lets;
use BDD::Behave::Value;
use Test;

plan 9;

my $v;

# symbols from the Lets scope stack
Lets.put(:name(':foo'), :block({1}));
$v = Value.new(:raw(':foo'));
ok $v.get() == 1, ':foo is 1';

Lets.put(:name(':bar'), :block({'2'}));
$v = Value.new(:raw(':bar'));
ok $v.get() == '2', ":bar is '2'";

Lets.put(:name(':baz'), :block({"3"}));
$v = Value.new(:raw(':baz'));
ok $v.get() == '3', ":baz is '3'";

# numerics
$v = Value.new(:raw('4'));
ok $v.get() == 4, 'is 4';

$v = Value.new(:raw("5"));
ok $v.get() == 5, 'is 5';

# quoted numerics
$v = Value.new(:raw("'6'"));
ok $v.get() == 6, 'is 6';

$v = Value.new(:raw('"7"'));
ok $v.get() == 7, 'is 7';

# quoted strings
$v = Value.new(:raw("'foo'"));
ok $v.get() eq 'foo', 'is "foo"';

$v = Value.new(:raw('"bar"'));
ok $v.get() eq 'bar', 'is "bar"';

done-testing;
