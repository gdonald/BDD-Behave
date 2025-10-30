## Spec Tree Overview

The new executable runner will build an in-memory tree of spec nodes as the DSL executes. The data model lives in `BDD::Behave::SpecTree` and provides three primary node types:

- `Suite`: root container for all loaded files. Stores metadata such as CLI flags and holds top-level example groups.
- `ExampleGroup`: corresponds to `describe`/`context`. Holds child groups and examples plus registered hooks (`before-all`, `after-all`, `before-each`, `after-each`) and arbitrary metadata.
- `Example`: represents an `it` block. Stores the example block, its source location, and extra metadata (pending state, tags, etc.).

Each node records a `description`, `file`, and `line` so failure reports can reference original source positions. Nodes keep a reference to their parent so a runner can quickly compute nested descriptions or inheritance chains.

### Runner Flow

1. DSL helpers instantiate `ExampleGroup`/`Example` nodes while the spec file executes and attach them to the active parent node.
2. Once the spec file finishes loading, the runner walks the `Suite` tree depth-first.
3. For each `ExampleGroup`, the runner:
   - runs `before-all` hooks once,
   - executes each example (with `before-each`/`after-each` hooks),
   - then runs `after-all` hooks.
4. `Example.execute` simply calls the stored block with the current evaluation context. Higher layers will inject resolved `let` values or other helpers when they become available.

This structure keeps the DSL surface small while capturing everything the runner needs to schedule execution and report results.
