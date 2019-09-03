## Behave
A behavior driven development framework written in [Perl 6](https://perl6.org/).

Currently developed against Rakudo `v6.d`.

#### Example Output:

![Behave](https://raw.githubusercontent.com/gdonald/behave/master/screen-shot.png)

#### Install from CPAN

```
zef install --/test BDD::Behave
```

#### Running Behave:

Behave will automatically look for a `specs` directory and will run anything matching `/spec.p6/`.

You can run a specific spec file like this:

```
$ behave specs/001-spec.p6
```

#### Status

[![Build Status](https://travis-ci.org/gdonald/BDD-Behave.svg?branch=master)](https://travis-ci.org/gdonald/BDD-Behave)

#### Documentation

No docs yet, see the examples in [specs/*](https://github.com/gdonald/BDD-Behave/tree/master/specs).

#### License

Behave is released under the [Artistic License 2.0](https://opensource.org/licenses/Artistic-2.0)
