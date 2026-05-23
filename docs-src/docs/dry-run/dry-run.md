# Dry run and listing

Behave can load spec files and report what *would* run without actually executing any example. Two CLI flags surface this from different angles:

- `--dry-run` is for humans: a hierarchical, indented listing followed by an `N example(s)` count.
- `--list-examples` is for tools: one line per example (or a JSON document) suitable for editor integrations.

Both flags honor `--tag`, `--exclude-tag`, `--example`, `--only-example`, focus mode (`fit`/`fdescribe`), and skip metadata (`xit`/`xdescribe`).

## `--dry-run`

```text
$ behave --dry-run specs/cart-spec.raku
Cart
  adding items
    increments the count
    updates the total price
    persists across reloads (PENDING)
  removing items
    decrements the count
    is intentionally skipped (SKIPPED)

5 examples
```

Statuses appear in parentheses after the description:

- `(PENDING)` — declared with `pending`
- `(SKIPPED)` — declared with `xit` / `xdescribe` (or `:skipped` metadata)
- `(FOCUSED)` — declared with `fit` / `fdescribe` (or `:focused` metadata)

The trailing `N example(s)` line reports the count after filters.

### `--dry-run --verbose`

Adds each example's `file:line` and effective tag list (tags inherited from ancestor `describe`/`context` blocks are included):

```text
Cart
  adding items
    increments the count
      /path/to/cart-spec.raku:5
      tags: fast
    updates the total price
      /path/to/cart-spec.raku:6
```

### Exit code

`--dry-run` exits `0` when every spec file loaded cleanly, and `1` when at least one spec file failed to load. The exit code is independent of whether the filters matched any examples — zero matching examples is still a successful dry run.

## `--list-examples`

Plain-text mode prints one line per matching example. Each line is:

```
<absolute spec file>:<line><TAB><full nested description>
```

```text
$ behave --list-examples specs/cart-spec.raku
/path/to/cart-spec.raku:5	Cart adding items increments the count
/path/to/cart-spec.raku:6	Cart adding items updates the total price
/path/to/cart-spec.raku:7	Cart adding items persists across reloads
/path/to/cart-spec.raku:11	Cart removing items decrements the count
/path/to/cart-spec.raku:12	Cart removing items is intentionally skipped
```

The tab separator makes the format easy to parse with `cut -f1` (locations) or `cut -f2` (descriptions). Pair with `xargs behave --only-example` or your editor's "run this test" action.

### `--list-examples-format=json`

For richer integrations the JSON output exposes the same fields as the programmatic [`SpecRegistry` query API](#programmatic-query-api):

```text
$ behave --list-examples --list-examples-format=json specs/cart-spec.raku
```

```json
{
  "version": 1,
  "count": 5,
  "examples": [
    {
      "description": "increments the count",
      "full-description": "Cart adding items increments the count",
      "file": "/path/to/cart-spec.raku",
      "line": 5,
      "tags": ["fast"],
      "metadata": { "tags": ["fast"] },
      "pending": false,
      "focused": false,
      "skipped": false
    }
  ]
}
```

Field reference:

| Field              | Type              | Notes                                                     |
| ------------------ | ----------------- | --------------------------------------------------------- |
| `description`      | string            | The example's own description.                            |
| `full-description` | string            | Ancestor groups + example, joined with a space.            |
| `file`             | string            | Absolute path to the spec file.                            |
| `line`             | integer           | Line of the `it` (or `fit`/`xit`/`pending`).               |
| `tags`             | list of strings   | Effective tags (own + inherited from ancestor groups).     |
| `metadata`         | object            | The example's own metadata (excluding the internal `lets`).|
| `pending`          | boolean           | Declared with `pending` or marked pending.                 |
| `focused`          | boolean           | Effectively focused (own or via an ancestor `fdescribe`).  |
| `skipped`          | boolean           | Effectively skipped (own or via an ancestor `xdescribe`).  |

Unknown future fields may appear; keep your parser tolerant.

## Programmatic query API

Tooling that wants to drive Behave from inside a Raku process (without parsing CLI output) should use `BDD::Behave::SpecRegistry`'s query methods directly.

```raku
use BDD::Behave::SpecRegistry;

# After your spec files have been loaded (e.g. via EVALFILE), the
# global registry holds every Suite/ExampleGroup/Example node.
my $reg = BDD::Behave::SpecRegistry::registry();

# Every example across every loaded suite, as ExampleQueryResult records:
my @all = $reg.all-examples;

# Filtered query — every kwarg below is optional and ANDed:
my @hits = $reg.query-examples(
  description-pattern => '/^Cart\s/',     # substring or /regex/
  file                => 'cart-spec.raku',# basename, relative, or absolute
  line                => 5,
  include-tags        => ['fast'],         # OR across listed tags
  exclude-tags        => ['slow'],         # ANDed with the rest
  metadata            => { type => 'unit' },
  metadata-exclude    => { type => 'integration' },
  pending             => False,
  focused             => True,
  skipped             => False,
);

# Count without materializing the records:
my $n = $reg.count-examples(include-tags => ['fast']);
```

Each `ExampleQueryResult` exposes:

- `.description` / `.full-description`
- `.file` (`IO::Path`) / `.line` / `.location`
- `.suite-file` (`IO::Path`) / `.suite-description`
- `.group-descriptions` (list of strings, outermost first)
- `.tags` (effective tags)
- `.metadata` (own metadata hash with the internal `lets` key removed)
- `.pending` / `.focused` / `.skipped` (Bool)
- `.to-hash` for serialization (used by `--list-examples-format=json`)

This API is stable for editor and IDE integrations; the CLI `--list-examples` output is a thin wrapper over it.
