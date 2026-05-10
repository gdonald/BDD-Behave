# Tags

Tags are metadata you attach to examples or groups so the runner can include or exclude subsets of your spec suite at run time. They are useful for separating slow tests, integration tests, flaky tests, or any other axis you want to filter on.

## Tagging an example

Pass `:tag<name>` to `it`:

```raku
describe 'Order', {
  it 'totals correctly',          :tag<fast>,     { ... }
  it 'rounds tax to two places',  :tag<fast>,     { ... }
  it 'reaches the payment API',   :tag<integration>, { ... }
}
```

Use `:tags<a b c>` to attach more than one tag at once:

```raku
it 'recovers from API timeouts', :tags<integration flaky>, {
  ...
}
```

## Tagging a group

`describe` and `context` accept the same arguments. Group-level tags are inherited by every example inside the group, including examples in nested groups.

```raku
describe 'Payment processing', :tag<integration>, {
  it 'authorizes a card', { ... }   # effective tag: integration
  it 'voids a charge',     { ... }  # effective tag: integration

  context 'when the gateway is down', :tag<network>, {
    it 'retries 3 times', :tag<flaky>, {
      # effective tags: integration, network, flaky
    }
  }
}
```

## Filtering at the command line

The `behave` CLI exposes two repeatable flags:

| Flag | Effect |
| --- | --- |
| `--tag NAME` | Run only examples whose effective tags include `NAME`. Repeat for OR semantics. |
| `--exclude-tag NAME` | Skip examples whose effective tags include `NAME`. Repeat to skip several tags. |

```shell
$ behave --tag fast
$ behave --tag integration --tag smoke
$ behave --exclude-tag flaky
$ behave --tag integration --exclude-tag flaky
```

Both forms support `--tag=NAME` if you prefer the `=` style.

## Precedence rules

- An example runs only if it matches at least one `--tag` (when any are given) **and** matches none of the `--exclude-tag` values.
- `--exclude-tag` always wins over `--tag` for the same example.
- A group is walked only when at least one of its descendants would run.
- With no flags, every example runs (existing behavior is preserved).

## Inspecting tags programmatically

Each `Example` and `ExampleGroup` exposes:

- `.tags` — tags attached directly to that node.
- `.effective-tags` — tags from this node and every ancestor, deduplicated.
- `.has-tag('name')` / `.has-effective-tag('name')` — boolean checks.

These helpers are useful for custom reporters or tooling built on top of the runner.
