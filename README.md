## Behave

A behavior-driven testing framework written in [Raku](https://raku.org/).

Currently developed against Raku `v6.d`.

#### Install using zef

```bash
zef install BDD::Behave
```

#### Running Behave

If no file is specified, Behave looks for a `specs/` directory and runs every file in it whose name matches `*spec.raku`.

#### An example

**specs/answer-spec.raku**

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

  it 'fails at line 15', {
    expect(:answer).to.be(41);
  }
}
```

You can run the spec like this:

```bash
behave --format=tree specs/answer-spec.raku
```

Output:

```console
⮑ 'this spec'
  ⮑ 'passes'
    ⮑ SUCCESS
⮑ 'this final spec'
  ⮑ 'fails at line 15'
    ⮑ FAILURE

Failures:

  [ ✗ ] /path/to/project/specs/answer-spec.raku:15
      this final spec fails at line 15
      Expected: 42
      to be: 41

2 examples, 1 failed, 1 passed
Randomized with seed 581808742
```

#### Local Behave development

For local development of Behave itself:

```bash
raku -Ilib bin/behave
```

#### Tests

To run the full test suite (both `t/` and `specs/`):

```bash
raku test.raku
```

To run just the `t/` tests:

```bash
prove6 -Ilib t
```

#### Status

[![CI](https://github.com/gdonald/BDD-Behave/actions/workflows/ci.yml/badge.svg)](https://github.com/gdonald/BDD-Behave/actions/workflows/ci.yml)

#### Documentation

Documentation: [https://gdonald.github.io/BDD-Behave/](https://gdonald.github.io/BDD-Behave/)

See also the examples in [specs/*](https://github.com/gdonald/BDD-Behave/tree/main/specs).

#### Website

[https://behave.dev](https://behave.dev)

#### License

Copyright (c) 2019-2026 Greg Donald

This software is licensed under the Artistic License 2.0.

[![GitHub](https://img.shields.io/github/license/gdonald/BDD-Behave?color=4b0082)](https://github.com/gdonald/BDD-Behave/blob/main/LICENSE)
