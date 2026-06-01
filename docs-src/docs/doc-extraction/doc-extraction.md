# Documentation extraction

Behave can turn your spec tree into a hierarchical document of behaviors, no execution required. This is useful for living documentation: the descriptions you already wrote on `describe`, `context`, and `it` become a stand-alone document that you can publish, paste into a PR, or hand to a non-engineer stakeholder.

## Quick start

```shell
$ behave --doc specs/calculator-spec.raku
# Calculator

## addition

- adds two positive numbers
- adds a positive and zero
- handles overflow (PENDING)

## subtraction

- subtracts two positive numbers
- handles negative results
```

`--doc` loads each spec file (so `describe` / `context` / `it` register their tree), then walks the tree and prints. Examples are never executed: there are no pass/fail counts, no timing, no formatters.

## Output formats

`--doc-format=FORMAT` chooses the output format. Three formats are built in:

| Format     | Use case                                                                        |
| ---------- | ------------------------------------------------------------------------------- |
| `markdown` | Default. Human-readable. Renders cleanly on GitHub, MkDocs, and most wikis.     |
| `html`     | Standalone HTML document (`<!DOCTYPE html>` + `<section>` + `<ul>`).            |
| `json`     | Machine-readable nested tree for downstream tooling.                            |

### Markdown

```text
# <group-description>
## <nested-group-description>
- <example-description>
- <example-description> (PENDING)
```

Each `describe` or `context` becomes a Markdown heading. Depth maps to the number of `#`s (capped at six). Each `it` / `pending` / `xit` becomes a bullet under its enclosing group. Status suffixes:

| State    | Suffix      |
| -------- | ----------- |
| Passing  | *(none)*    |
| Pending  | `(PENDING)` |
| Skipped  | `(SKIPPED)` |
| Focused  | `(FOCUSED)` |

If the example carries tags, they appear in square brackets after the description: `- example description [user-facing, smoke]`.

When you pass multiple spec files, each suite gets its own top-level `# <file>` heading and groups start at `##`.

### HTML

The HTML format wraps everything in semantic tags so it is easy to style:

```html
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><title>Spec documentation</title></head>
<body>
<section class="suite">
<h1>demo-spec.raku</h1>
<section class="group">
<h2>Calculator</h2>
<section class="group">
<h3>addition</h3>
<ul class="examples">
<li class="example status-passing">adds two positive numbers</li>
<li class="example status-pending">handles overflow <em class="status">(pending)</em></li>
</ul>
</section>
</section>
</section>
</body>
</html>
```

All descriptions are HTML-escaped. Status classes (`status-passing`, `status-pending`, `status-skipped`, `status-focused`) let you style each state in CSS.

### JSON

The JSON format emits a single object with a stable schema so downstream tools can ingest it without scraping text:

```json
{
  "version": 1,
  "suites": [
    {
      "description": "demo-spec.raku",
      "file": "/abs/path/demo-spec.raku",
      "examples": [],
      "groups": [
        {
          "description": "Calculator",
          "file": "/abs/path/demo-spec.raku",
          "line": 3,
          "tags": [],
          "examples": [],
          "groups": [
            {
              "description": "addition",
              "file": "/abs/path/demo-spec.raku",
              "line": 5,
              "tags": [],
              "groups": [],
              "examples": [
                {
                  "description": "adds two positive numbers",
                  "file": "/abs/path/demo-spec.raku",
                  "line": 6,
                  "tags": ["user-facing"],
                  "pending": false,
                  "skipped": false,
                  "focused": false
                }
              ]
            }
          ]
        }
      ]
    }
  ]
}
```

The schema is:

- `version` (integer): currently `1`.
- `suites` (array): one entry per loaded spec file.
  - `description` (string): the suite's display name (usually the file basename).
  - `file` (string): absolute path.
  - `groups` (array): nested groups (recursive).
  - `examples` (array): examples that live directly under the suite (rare).
- Each group has `description`, `file`, `line`, `tags`, `groups`, `examples`.
- Each example has `description`, `file`, `line`, `tags`, `pending`, `skipped`, `focused`.

JSON keys are sorted alphabetically within each object for stable diff-friendly output.

## Writing to a file

By default `--doc` prints to stdout. Pass `--doc-output PATH` to write to a file instead:

```shell
$ behave --doc --doc-format=html --doc-output build/specs.html specs/
```

When `--doc-output` is set, stdout stays clean, useful inside CI pipelines or shell scripts that want to combine multiple Behave runs.

## Filtering with tags and metadata

Documentation honors the same filtering flags as the runner. Pass `--tag`, `--exclude-tag`, or `--example` together with `--doc` to emit only a subset of behaviors:

```shell
# Only public-facing behaviors
$ behave --doc --tag user-facing specs/

# Drop internal-only specs from the public docs
$ behave --doc --exclude-tag internal specs/

# Substring or /regex/ match on the full nested description
$ behave --doc --example 'adds two' specs/
$ behave --doc --example '/handles\s\w+/' specs/
```

Filtering semantics:

- Tag inheritance follows the runner's rules: a tag on a `describe` applies to every `it` inside it.
- Groups whose examples are all filtered out are dropped from the output entirely, so you don't see hollow `## addition` headings with no bullets underneath.
- An example must match every active filter (AND across filter families) but a single tag or pattern hit is enough within a family (OR within a family).
- If nothing matches, the output is empty.

`--example PATTERN` supports two forms: a bare substring (matched against the full nested description, e.g. `Calculator addition adds two positive numbers`), or a `/regex/` form where the body is compiled as a Raku regex. Note: spaces inside the regex are ignored (Raku regex grammar). Use `\s` to match whitespace.

## What is *not* in the output

`--doc` describes **behaviors**, not implementation. The following are intentionally omitted:

- `before-each` / `after-each` / `around-each` / `before-all` / `after-all` hooks.
- `let` and `subject` definitions.
- `include-context` / `include-examples` boilerplate.
- Example bodies (only descriptions are emitted).

The goal is a behavior-focused outline that is meaningful to readers who do not (and should not need to) read the test source.

## Exit code

`--doc` exits `0` on success. If any spec file fails to load (a syntax error, a missing dependency), it prints the error to stderr and exits `1`, but it still tries to emit a document for the files that *did* load, so you can see partial progress.

## Programmatic use

Under the hood `--doc` is a thin wrapper around `BDD::Behave::DocExtractor`, which you can use from your own code:

```raku
use BDD::Behave::DocExtractor;
use BDD::Behave::SpecRegistry;

# Spec files have already been EVALFILE'd at this point...
my @suites = BDD::Behave::SpecRegistry::suites();

my $extractor = BDD::Behave::DocExtractor::DocExtractor.new(
  :format<markdown>,
  :include-tags(<user-facing>),
);

print $extractor.extract(@suites);
```

Constructor parameters:

| Parameter                  | Default      | Effect                                           |
| -------------------------- | ------------ | ------------------------------------------------ |
| `format`                   | `'markdown'` | One of `markdown`, `html`, `json`.               |
| `include-tags`             | empty list   | Only keep examples that have at least one tag.   |
| `exclude-tags`             | empty list   | Drop examples that have any of these tags.       |
| `example-patterns`         | empty list   | Substring or `/regex/` matched on full description. |
| `metadata-filters`         | empty hash   | Keep examples where `effective-metadata-value(key) eq expected`. |
| `metadata-exclude-filters` | empty hash   | Drop examples matching the same predicate.       |

`extract(@suites)` returns a `Str` in the chosen format.
