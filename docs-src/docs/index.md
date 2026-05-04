# BDD::Behave

The latest version of this documentation lives at [https://gdonald.github.io/BDD-Behave/](https://gdonald.github.io/BDD-Behave/).

The homepage for BDD::Behave is [https://github.com/gdonald/BDD-Behave](https://github.com/gdonald/BDD-Behave).

## Synopsis

BDD::Behave is a behavior-driven development framework for [Raku](https://raku.org/). Specs are ordinary Raku files that `use BDD::Behave;` and call exported DSL helpers (`describe`, `context`, `it`, `let`, `before-each`, `expect`, …) to build and run a tree of examples.

Currently developed against Raku `v6.d`.

## Example Usage

`specs/001-spec.raku`

```raku
use BDD::Behave;

describe 'this spec', {
  let(:answer, { 42 });

  it 'passes', {
    expect(:answer).to.be(42);
  }
}

describe 'this final spec', {
  let(:answer, { 42 });

  it 'fails at line 12', {
    expect(:answer).to.be(41);
  }
}
```

Run it with the `behave` runner:

```shell
$ behave specs/001-spec.raku
```

Output:

```
specs/001-spec.raku

⮑  'this spec'
  ⮑  'passes'
      ⮑  SUCCESS

⮑  'this final spec'
  ⮑  'fails at line 12'
      ⮑  FAILURE

Failures:

  [ ✗ ] specs/001-spec.raku:12

2 examples, 1 failed, 1 passed
```

## Install

BDD::Behave can be installed using the zef module installation tool:

```shell
zef install BDD::Behave
```
