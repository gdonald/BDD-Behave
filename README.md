## Behave
A behavior driven development framework written in [Perl 6](https://perl6.org/).

Currently developed against Rakudo `v6.d`.

#### Example Output:

![Behave](https://raw.githubusercontent.com/gdonald/behave/master/screen-shot.png)

#### Run Example Behave Specs:

```
$ perl6 -Ilib bin/behave
```

#### Run Tests:

```
$ prove --exec=perl6 --ext=t6
```

`prove6` has some issues running these tests `¯\_(ツ)_/¯`

#### Status

[![Build Status](https://travis-ci.org/gdonald/BDD-Behave.svg?branch=master)](https://travis-ci.org/gdonald/BDD-Behave)

#### License

Behave is released under the [Artistic License 2.0](https://opensource.org/licenses/Artistic-2.0)
