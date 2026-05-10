# describe / context

`describe` and `context` define a group of related examples. They are aliases — pick whichever reads better in plain English. Groups can be nested arbitrarily.

## Basic usage

```raku
use BDD::Behave;

describe 'String methods', {
  it 'uppercases', {
    expect('hi'.uc).to.be('HI');
  }

  it 'reverses', {
    expect('abc'.flip).to.be('cba');
  }
}
```

## Nesting with `context`

`context` reads naturally for branching scenarios:

```raku
describe 'User#full-name', {
  context 'when both names are present', {
    it 'joins them with a space', {
      my $u = User.new(:first<Ada>, :last<Lovelace>);
      expect($u.full-name).to.be('Ada Lovelace');
    }
  }

  context 'when only the first name is present', {
    it 'returns the first name alone', {
      my $u = User.new(:first<Ada>);
      expect($u.full-name).to.be('Ada');
    }
  }
}
```

## Scoping

Plain Raku scoping rules apply inside a group block — `my $foo = 'bar'` declared inside a `describe` is visible to its examples and nested groups, and shadowing works as you'd expect.

```raku
describe 'shadowing', {
  my $value = 'outer';

  it 'sees the outer value', {
    expect($value).to.be('outer');
  }

  context 'inner', {
    my $value = 'inner';

    it 'sees the inner value', {
      expect($value).to.be('inner');
    }
  }
}
```
