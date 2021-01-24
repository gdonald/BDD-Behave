## Behave

A behavior driven development framework written in [Raku](https://raku.org/).

Currently developed against Raku `v6.d`.

#### Install using zef

```
zef install BDD::Behave
```

#### Running Behave:

If a file is not specificed Behave will automatically look for a `specs` directory and will run anything matching `/spec.p6/`.

#### An example:

**specs/001-spec.p6**

```perl6
use BDD::Behave;

describe -> 'this spec' {
  it -> 'passes' {
    expect(42).to.be(42);
  }
}

describe -> 'this final spec' {
  it -> 'fails at line 12' {
    expect(42).to.be(41);
  }
}
```

You can run the spec like this:

```
$ behave specs/001-spec.p6
```

Output:

```perl6
specs/001-spec.p6

    ⮑  'this spec'
        ⮑  'passes'
            ⮑  SUCCESS

    ⮑  'this final spec'
        ⮑  'fails at line 12'
            ⮑  FAILURE

Failures:

  [ ✗ ] specs/001-spec.p6:12
```

#### Status

![Raku Status](https://github.com/gdonald/BDD-Behave/workflows/.github/workflows/test.yml/badge.svg)](https://github.com/gdonald/BDD-Behave/actions)

#### Documentation

No docs yet, see the examples in [specs/*](https://github.com/gdonald/BDD-Behave/tree/master/specs).

#### License

Behave is released under the [Artistic License 2.0](https://opensource.org/licenses/Artistic-2.0)
