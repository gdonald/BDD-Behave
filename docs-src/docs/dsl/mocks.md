# Doubles & Stubbing

Behave gives you two complementary ways to stand in for collaborators:

- **`double(...)`** creates a *new* stand-in object from scratch — useful when there's no real implementation to lean on.
- **`allow(obj).to.receive('method')`** *stubs a method on an existing object or class*, so the real type stays in play but specific calls are intercepted.

Both are exported from `BDD::Behave`. Stubs installed via `allow(...)` are automatically uninstalled at the end of each example, so they never leak between specs.

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

If your real collaborator uses one of these names, stub the method directly on a real instance with `allow(obj).to.receive(...)` instead.

# Stubbing real objects with `allow`

`allow($target).to.receive('method')` installs a temporary stub on a method of an existing class or instance. The stub is automatically uninstalled when the example ends, so the original implementation is restored before the next example runs.

The target can be:

- An **instance** — only that one instance gets the stub; sibling instances dispatch normally.
- A **class** (type object) — affects dispatch through the class itself (typically class methods).
- A **`Double`** — the stub is wired through the double's stub table.

## Return values

```raku
class Greeter {
  method hello($name) { "hello, $name" }
}

describe 'allow + and-return', {
  it 'stubs hello on this one instance', {
    my $g = Greeter.new;
    allow($g).to.receive('hello').and-return('STUB');

    expect($g.hello('alice')).to.be('STUB');
    expect(Greeter.new.hello('bob')).to.be('hello, bob');
  }
}
```

`.and-return` is optional — calling `allow($g).to.receive('hello')` with no follow-up stubs the method to return `Any`.

## Raising exceptions

`.and-raise` makes the stubbed method throw the supplied exception:

```raku
allow($repo).to.receive('find').and-raise(X::AdHoc.new(payload => 'not found'));

my $msg = '';
try { $repo.find(7); CATCH { default { $msg = .message } } }
expect($msg).to.be('not found');
```

## Delegating to the real implementation

`.and-call-original` makes the stubbed method delegate back to the original. The most common use is "re-stubbing" a method back to its real behavior after a previous `allow` set up a return value:

```raku
allow($g).to.receive('hello').and-return('mocked');
expect($g.hello('a')).to.be('mocked');

allow($g).to.receive('hello').and-call-original;
expect($g.hello('a')).to.be('hello, a');
```

`.and-call-original` is not supported on a `Double` — there is no original implementation to call back to.

## Dynamic stubs

`.and-do(&callable)` invokes the supplied callable with the call's positional arguments. The callable's return value becomes the stubbed method's return value:

```raku
allow($g).to.receive('hello').and-do(-> $name { "STUB($name.uc())" });

expect($g.hello('alice')).to.be('STUB(ALICE)');
```

## Replacement semantics

A second `allow($t).to.receive('m')` on the same target+method pair *replaces* the first stub. Only one allow-stub per `(target, method)` is active at a time:

```raku
allow($g).to.receive('hello').and-return('first');
allow($g).to.receive('hello').and-return('second');

expect($g.hello('a')).to.be('second');
```

## Stubs in `before-all` vs `before-each`

Auto-cleanup is per-example: a stub installed inside an `it` (or in `before-each`) is removed before the next example. A stub installed in `before-all` lives for the entire `describe` it sits in:

```raku
describe 'group-wide stub', {
  before-all {
    allow(Repo).to.receive('find').and-return('group-stub');
  }

  it 'first example sees it', { expect(Repo.find(1)).to.be('group-stub') }
  it 'second example also sees it', { expect(Repo.find(2)).to.be('group-stub') }
}
```

## Verifying stubs

`allow($t).to.receive('m')` rejects method names that don't exist on the target's class. This catches typos and stubs that drift out of sync with the real implementation:

```raku
allow($g).to.receive('imaginary');   # dies — no such method on Greeter
allow(Greeter).to.receive('also-no'); # dies — same check on the class
```

For a class-based `Double`, the stubbed method must exist on the wrapped class.

# Spies and `have-received`

Doubles record their calls automatically. To record calls on a *real* object, install an `allow(...).to.receive(...)` stub or use `spy(...)`. Then verify with `expect(obj).to.have-received('method')`.

## `spy(...)` — pass-through recorder

`spy()` has three forms:

| Form                          | Result                                                                  |
| ----------------------------- | ----------------------------------------------------------------------- |
| `spy()` / `spy('Name')`       | Same as `double()` / `double('Name')`. Permissive recording double.     |
| `spy(SomeClass)`              | Same as `double(SomeClass)`. Class-based verifying double.              |
| `spy($real-instance)`         | Wraps each user-defined method on the instance with a recording stub that delegates to the real implementation. Returns the same instance. |

```raku
class Greeter { method hello($name) { "hello, $name" } }

describe 'spying on a real object', {
  it 'records calls without changing behavior', {
    my $g = Greeter.new;
    spy($g);

    expect($g.hello('alice')).to.be('hello, alice');
    expect($g).to.have-received('hello');
  }
}
```

A spy on a real instance only affects that one instance — sibling instances dispatch normally. Stubs installed by `spy(...)` are auto-cleaned at end of example, like `allow(...)` stubs.

## `expect(obj).to.have-received('method')`

`have-received` checks call records on a Double, on a `spy(...)`-wrapped instance, or on any object whose method has been stubbed via `allow(...)`.

```raku
my $log = double('Logger');
$log.info('starting');

expect($log).to.have-received('info');     # at least one call
```

For real objects, you must install a recorder first (via `allow(...)` or `spy(...)`):

```raku
my $repo = Repo.new;
allow($repo).to.receive('find').and-call-original;

$repo.find(7);
expect($repo).to.have-received('find');
```

If no stub is installed when verifying a real object, `have-received` records a clear failure asking you to set one up.

`expect(obj).not.to.have-received('m')` asserts the method was *not* called.

## Call-count modifiers

| Modifier        | Meaning                              |
| --------------- | ------------------------------------ |
| `.once`         | exactly 1 call                       |
| `.twice`        | exactly 2 calls                      |
| `.thrice`       | exactly 3 calls                      |
| `.times(n)`     | exactly N calls                      |
| `.exactly(n)`   | alias for `.times(n)`                |
| `.at-least(n)`  | N or more calls                      |
| `.at-most(n)`   | N or fewer calls                     |

```raku
expect($log).to.have-received('info').twice;
expect($log).to.have-received('info').at-least(2);
expect($log).to.have-received('info').at-most(3);
```

Each chained modifier *replaces* any failure recorded by the previous step, so chains like `.have-received('m').with('a').twice` produce at most one failure even if the first check would have failed on its own.

## Argument matching: `.with(...)`

`.with(args)` filters the recorded calls and only counts those whose args match.

```raku
$log.info('starting');
$log.info('done');

expect($log).to.have-received('info').with('starting');     # passes
expect($log).to.have-received('info').with('starting').once; # passes
```

Both positional and named args are supported:

```raku
allow($g).to.receive('greet').and-return('hi');
$g.greet(:lang<en>);
expect($g).to.have-received('greet').with(:lang<en>);
```

## Argument matchers

For each positional or named arg, you can supply a matcher object instead of a literal value:

| Matcher                          | Matches                                                          |
| -------------------------------- | ---------------------------------------------------------------- |
| `anything`                       | Any value, including undefined.                                  |
| `instance-of(Type)`              | Anything for which `$arg ~~ Type` is true.                       |
| `hash-including(:k<v>, ...)`     | Any `Associative` containing the listed key/value pairs.         |
| `array-including(item, ...)`     | Any `Positional` containing all the listed items.                |

```raku
$log.info('hello', 42);
expect($log).to.have-received('info').with(instance-of(Str), instance-of(Int));

$log.info({ user => 'alice', region => 'us', extra => 1 });
expect($log).to.have-received('info').with(hash-including(user => 'alice'));

$log.info([1, 2, 3, 4, 5]);
expect($log).to.have-received('info').with(array-including(2, 4));
```

Matchers nest inside `hash-including` and `array-including`:

```raku
expect($log).to.have-received('info').with(
  hash-including(user => instance-of(Str), count => anything)
);
```

## Limits

- `allow($obj).to.receive('m')` only stubs `$obj`. To stub the same instance method across **all** instances of a class, pass the class type object instead — but that affects dispatch through the class itself, which mostly matches class-method semantics. A dedicated `allow_any_instance_of`-style helper isn't yet implemented.
- `spy($real-instance)` wraps user-defined methods; methods inherited from `Mu`/`Any` and submethods (e.g. `BUILD`, `POPULATE`) are not wrapped.
