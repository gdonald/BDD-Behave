## Behave

A behavior driven development framework written in [Raku](https://raku.org/).

Currently developed against Raku `v6.d`.

#### Install using zef

```
zef install BDD::Behave
```

#### Running Behave:

If a file is not specified Behave will automatically look for a `specs` directory and will run anything matching `/spec.raku/`.

#### An example:

**specs/001-spec.raku**

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

You can run the spec like this:

```
$ behave specs/001-spec.raku
```

Output:

```raku
specs/001-spec.raku

    ⮑  'this spec'
        ⮑  'passes'
            ⮑  SUCCESS

    ⮑  'this final spec'
        ⮑  'fails on the next line'
            ⮑  FAILURE

Failures:

  [ ✗ ] specs/001-spec.raku:12
```

#### Local Behave development:

For local development of Behave itself:

```
raku -Ilib bin/behave
```

#### Prove Tests

To run the tests in t/*:

```
prove6 -Ilib t
```

#### Status

[![.github/workflows/raku.yml](https://github.com/gdonald/BDD-Behave/workflows/.github/workflows/raku.yml/badge.svg)](https://github.com/gdonald/BDD-Behave/actions)

#### Documentation

See the examples in [specs/*](https://github.com/gdonald/BDD-Behave/tree/master/specs).

#### License

Behave is released under the [Artistic License 2.0](https://opensource.org/licenses/Artistic-2.0)
