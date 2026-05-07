# Doubles

A *double* is a stand-in object you create inside a spec to take the place of a collaborator that's irrelevant, expensive, or inconvenient to construct for real. The double records every method called on it, and any call that has been pre-configured returns the value you supplied.

`double` is exported from `BDD::Behave`.

This page covers the basics: creating doubles, stubbing return values, and asserting which methods were called. More expressive stubbing (`allow(...).to.receive(...)`) and call-argument matchers will land in later releases.

## Creating an ad-hoc double

The simplest form takes a name and a list of `method => value` pairs:

```raku
use BDD::Behave;

describe 'order summary', {
  it 'reads name and total from a user double', {
    my $user = double('User', name => 'alice', total => 99);

    expect($user.name).to.be('alice');
    expect($user.total).to.be(99);
  }
}
```

The name is purely cosmetic — it shows up in error messages from the double itself.

`double()` with no arguments produces an *anonymous* double:

```raku
my $d = double;
$d.poke;
expect($d.received('poke')).to.be(True);
```

## What unstubbed methods do

Calling a method on an ad-hoc double that you didn't stub returns `Any`. The call is still recorded, so you can verify it happened:

```raku
my $log = double('Logger');
$log.warn('careful');                    # returns Any
expect($log.received('warn')).to.be(True);
```

This makes ad-hoc doubles permissive by design — they let you focus on the calls you actually care about.

## Callable stubs

If the stub value is a `Callable`, the double invokes it with the call's arguments and returns the result:

```raku
my $upper = double('Upper', shout => -> $s { $s.uc });

expect($upper.shout('hi')).to.be('HI');
```

This is useful when the return value should depend on the input.

## Adding stubs after creation

`add-stub` accepts the same `method => value` pairs as `double()` and returns the double, so you can chain:

```raku
my $cfg = double('Config').add-stub(theme => 'dark', font => 'mono');

expect($cfg.theme).to.be('dark');
expect($cfg.font).to.be('mono');
```

## Verifying calls

Every call is captured. The double exposes a small set of methods for asking what happened:

| Method                  | Returns                                                                   |
| ----------------------- | ------------------------------------------------------------------------- |
| `received($method)`     | `True` if `$method` was called at least once.                             |
| `call-count($method)`   | Number of times `$method` was called.                                     |
| `calls-of($method)`     | List of `Call` objects for `$method`, in the order they happened.         |
| `calls`                 | List of every `Call` made on the double.                                  |
| `reset`                 | Clears the recorded calls (stubs survive).                                |

A `Call` exposes `method`, `args` (positional), `named`, `file`, and `line`.

```raku
my $log = double('Logger');
$log.info('starting');
$log.warn('careful', :reason<low-disk>);

expect($log.call-count('info')).to.be(1);
expect($log.calls-of('warn')[0].named<reason>).to.be('low-disk');
```

## Class-based doubles

Pass a class as the first argument and the double becomes *verifying*: every stubbed method must exist on the class, and dispatching a method the class doesn't have dies. This catches typos and stubs that drift out of sync with the real implementation.

```raku
class Greeter {
  method hello($name) { "hello, $name" }
}

describe 'class-based double', {
  it 'stubs only methods that exist on the class', {
    my $g = double(Greeter, hello => 'mocked');

    expect($g.hello('world')).to.be('mocked');
    expect($g.double-class === Greeter).to.be(True);
    expect($g.double-name).to.be('Greeter');
  }
}
```

What you can't do with a class-based double:

- Stub a method the class doesn't define — `double(Greeter, missing => 1)` dies at creation.
- Call a method the class doesn't define — `$g.bogus` dies at dispatch.

The double does *not* invoke the real implementation; the class is only consulted for validation.

## Reserved method names

Because `Double` exposes the verification API on the same object you call stubbed methods on, a handful of method names are reserved and cannot be used as stub keys:

`add-stub`, `call-count`, `calls`, `calls-of`, `double-class`, `double-name`, `received`, `reset`, `stubs`.

If your real collaborator uses one of these names, you'll need to assert the call indirectly (e.g. by routing the dispatch through a wrapper) until 4.4.2 lands more flexible stubbing.
