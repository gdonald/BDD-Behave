
use v6.d;
use lib 'lib';
use BDD::Behave::Lets;
use Test;

plan 13;

ok Lets.scopes.elems == 0;

Lets.put(:name(':foo'), :block({1}));
ok Lets.scopes.elems == 1;
ok Lets.get(':foo') == 1;

Lets.push-scope();
ok Lets.scopes.elems == 2;
Lets.put(:name(':foo'), :block({2}));
ok Lets.get(':foo') == 2;

Lets.push-scope();
ok Lets.scopes.elems == 3;
Lets.put(:name(':foo'), :block({3}));
ok Lets.get(':foo') == 3;

Lets.pop-scope();
ok Lets.scopes.elems == 2;
ok Lets.get(':foo') == 2;

Lets.pop-scope();
ok Lets.scopes.elems == 1;
ok Lets.get(':foo') == 1;

Lets.pop-scope();
ok Lets.scopes.elems == 0;
ok !Lets.get(':foo');
