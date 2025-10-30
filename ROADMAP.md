## Vision
Transition BDD::Behave from a grammar-driven DSL to an executable, RSpec-style runner where specs are ordinary Raku code that call exported DSL helpers. This lets spec authors use normal scoping, helper subs, control flow, and data setup without extending a bespoke grammar.

## Current Limitations
- Specs are parsed, not executed, so any new construct requires grammar and action support.
- Variable bindings such as `my $foo = 'bar'` are invisible, pushing users toward hacks like `# DATA-BEGIN` blocks.
- `Value.evaluate` relies on string pattern matching and `EVAL`, which is brittle and unsafe.
- The spec runner has no concept of executable hooks or richer expectation helpers because the grammar cannot cover general Raku.

## Guiding Principles
- Treat spec files as standard Raku modules that `use BDD::Behave;` and execute code directly.
- Expose a DSL via exported subs/macros (`describe`, `it`, `let`, `expect`, etc.) that build a runtime spec tree.
- Preserve the existing public surface (CLI, colors, expectation output) where practical, while improving ergonomics.

## Development Roadmap:

### Milestone 1: Prepare the New Runner
- [x] Design and land `BDD::Behave::SpecTree` (e.g., `Suite`, `ExampleGroup`, `Example`) to represent describes/its and metadata.
- [x] Introduce a registry (`BDD::Behave::SpecRegistry`) to manage per-file suites and the nested group stack.
- [x] Implement exported `describe`/`context`/`it` routines that register blocks at compile time (macros or BEGIN blocks) and defer execution.
- [ ] Reimplement `let` as a lexical helper that supports per-example memoization and scope stacking without the current `Lets` store.
- [ ] Port expectation handling to accept actual values rather than strings and ensure failure reporting stays compatible.
- [ ] Build a new runner module that walks the registered spec tree and executes examples with proper setup/teardown semantics.

### Milestone 2: Incremental Adoption
- [ ] Introduce feature flag (e.g., `use BDD::Behave :v2;`) so both runners coexist during migration.
- [ ] Convert a single spec file (start with `specs/001-basic-spec.raku`) to the new style; add tests covering mixed usage.
- [ ] Update CLI (`bin/behave`) to dispatch to old or new runner based on flag or environment variable.
- [ ] Document the new spec authoring style alongside the legacy one in `README.md`.

### Milestone 3: Full Migration
- [ ] Migrate remaining specs to the executable style; remove grammar-specific constructs from fixtures.
- [ ] Replace lexer/parser-driven modules (`Grammar`, `Actions`, `Lets`, etc.) with new runtime (mark deprecated first).
- [ ] Add comprehensive tests for the new runner, including nested `describe`, hooks, and failure reporting.
- [ ] Ensure performance is on par or better and that failure output matches existing formatting expectations.

### Milestone 4: Cleanup and Enhancements
- [ ] Remove legacy grammar code after one release cycle; bump major version if public API changes.
- [ ] Add higher-level conveniences (shared contexts, hooks, pending examples) now feasible with executable specs.
- [ ] Harden expectation library to leverage real values (type-aware diffs, matcher architecture).
- [ ] Revisit security posture: eliminate remaining `EVAL` usage in favor of direct execution.

### Communication & Release
- Draft migration notes and examples for users; highlight benefits and necessary edits.
- Tag an alpha release once Milestone 2 is stable; gather feedback before removing the old runner.
- Track user issues in the issue tracker; adjust milestones as real-world usage surfaces edge cases.
