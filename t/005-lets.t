
use lib 'lib';
use BDD::Behave::Lets;
use Test;

plan 13;

ok Lets.scopes.elems == 0, 'scopes.elems is 0';

# first scope
Lets.put(:name(':foo'), :block({1}));
ok Lets.scopes.elems == 1, 'scopes.elems is 1';
ok Lets.get(':foo') == 1, 'in first scope :foo is 1';

# second scope
Lets.push-scope();
ok Lets.scopes.elems == 2, 'scopes.elems is 2';
Lets.put(:name(':foo'), :block({2}));
ok Lets.get(':foo') == 2, 'in second scope :foo is 2';

# third scope
Lets.push-scope();
ok Lets.scopes.elems == 3, 'scopes.elems is 3';
Lets.put(:name(':foo'), :block({3}));
ok Lets.get(':foo') == 3, 'in third scope :foo is 3';

# unwind
Lets.pop-scope();
ok Lets.scopes.elems == 2, 'scopes.elems is 2';
ok Lets.get(':foo') == 2, 'in second scope :foo is 2';

Lets.pop-scope();
ok Lets.scopes.elems == 1, 'scopes.elems is 1';
ok Lets.get(':foo') == 1, 'in first scope :foo is 1';

Lets.pop-scope();
ok Lets.scopes.elems == 0, 'scopes.elems is 0';
ok !Lets.get(':foo'), 'in first scope :foo is Nil';

done-testing;
