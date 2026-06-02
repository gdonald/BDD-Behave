# Changelog

## v0.9.1 — 2026-06-01

### Added

- Bareword slang for `let`, so blocks can reference fixtures as `owner` in
  addition to `:owner`
- `raise` and `throw` aliases for the `raise-error` exception matcher
- `--version` flag on the `behave` CLI

### Removed

- Per-example memory profiling.

### Fixed

- Parallel worker distribution and a `require` failure under `--parallel`
- Line number rendering in spec failure output

## v0.9.0 — 2026-05-25

Spec-tree runner with hooks, mocks, custom matchers, and parallel execution.

### Added

- **Documentation**
  - mkdocs site under `docs-src/`, published to the `gh-pages` branch at <https://gdonald.github.io/BDD-Behave/>
  - Spec-driven doc extraction
- **Core DSL**
  - `describe` / `it` / `specify` with arbitrary nesting on a spec tree
  - `before` / `after` / `around` hooks, including metadata-keyed and inherited variants
  - `let` / `let!` (eager) / `subject` / `is-expected` one-liner syntax
  - Shared contexts and shared examples
  - Tags, focus, and skip
  - Example filtering by name or metadata
  - Pending examples, dry-run, and example listing
  - Run by file, directory, line number, or a single block
- **Expectations**
  - Custom and composable matcher DSL
  - Matchers for equality, comparison, `be-between` / `be-within`, boolean, nil, type checking, `respond-to`, `have-attributes`, `include`, `all`, sequence, `match`, string content, `change` / `change-by` / `change-from-to`, junctions, exceptions (`raise-error` with attribute matching), promises, supplies/channels, and `eventually` for async
  - `aggregate_failures` block plus auto-aggregation
- **Mocks**
  - Doubles, method stubbing, spies with call verification, and partial mocking
- **Runner & CLI**
  - Parallel execution with queue distribution, a discovery subprocess, per-shard retry on worker crash, and aggregated memory / profile / benchmark output
  - `--fail-fast`, `--watch`, `--progress-total`, retry, seed control, and bisect for flaky specs
  - Code coverage metrics, compatible with `--parallel`
- **Formatters**
  - Progress (default), TAP, JUnit, JSON, JsonEvents, HTML, Tree, and Documentation
- **Diagnostics**
  - Junction-aware, shape-detecting diffs
  - Timing profiling, memory profiling, and benchmarking with baselines
  - Time mocking
- **Configuration**
  - File-based configuration with CLI precedence

### Changed

- Migrated files from Perl 6 file extensions to Raku throughout
- Reworked expectations to accept actual values
- Replaced the grammar-driven core with an in-memory spec tree (`Suite` → `ExampleGroup` → `Example` / `Hook`) walked by the runner
- Regrouped `lib/`, `t/`, and `specs/` by feature area (`core/`, `expectations/`, `parallel/`, etc.)
- Default formatter is now Progress

## v0.0.3 — 2019-09-14

Grammar-driven runner with a small DSL.

### Added

- `describe` / `context` / `it` blocks with nesting
- `let(:name) => { ... }` with block-scoped overrides
- `expect(x).to.be(y)` equality matcher, with `.to.not` for negation
- Variable interpolation in expectations (`expect(:foo).to.be(42)`, `expect(42).to.be(:foo)`)
- CLI `behave [path]` runner; auto-discovers `specs/*spec.p6` when no path is given
- Colorized output and failure reporting with file and line numbers
