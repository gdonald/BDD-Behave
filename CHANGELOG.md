# Changelog

## v0.9.5 — 2026-08-28

### Added

- The coverage report is built by CI and published to
  [https://coverage.behave.dev](https://coverage.behave.dev)

### Changed

- An omitted `--parallel` now defaults to the CPU core count. A selection that
  resolves to a single spec file still runs in this process with no workers,
  since reaching the parallel runner costs a precompile subprocess, a discovery
  subprocess, and a worker subprocess. Pass `--parallel 1` to put one file
  through a worker anyway. Under `--coverage` the omitted default stays at the
  core count for any file count
- The precompile pass is skipped for a selection of one spec file, and when
  discovery runs in this process. Nothing loads the spec files concurrently in
  either case, which is the only thing the pass protects against
- The default `--parallel-mode` and the set of modes it accepts come from
  `BDD::Behave::Configuration` rather than from a literal in `bin/behave`
- The ancestry walk of a spec node is cached, and the repeated work on the
  per-example path is cut, so a large suite spends less time between examples
- JSON events are emitted with less work per event
- A worker's output is collected without re-slicing the buffer after every
  line, and its events are parsed without scanning character by character
- Coverage log lines are parsed without regexes, and each file's covered-line
  set is computed once rather than on every read

### Fixed

- An expectation failure carrying no message of its own reached the JSON event
  stream and the parallel parent with an empty `message`. Both now render the
  same `Expected: ... / to be: ...` text the serial runner shows

### Removed

- The bundled `docs-src/` manual. The documentation is at
  [https://behave.dev/docs](https://behave.dev/docs)
- Three unreachable code paths: the read-only `STORE` on a `let` declared
  inside a running example, which the sub's return decontainerized before any
  caller could assign to it, and the basename comparison in location matching
  in `DryRun` and `Parallel`, which the path-suffix comparison above it already
  answered

## v0.9.4 — 2026-07-15

### Added

- A precompile pass before parallel discovery, building every spec file's module
  precompilation in one `--compile-only` subprocess so a single process writes
  the whole dependency graph and discovery and the workers only read it
- Recovery from a cache left inconsistent by earlier runs: a precompile pass
  that dies clears the project's reported `.precomp` directories and rebuilds
- `--no-precompile` to skip the precompile pass
- `--compile-only` to load the given spec files, writing their precompilation,
  and exit without running examples or printing

### Fixed

- A worker or the discovery subprocess killed by a signal such as SIGSEGV no
  longer reads as exit 0 and "0 examples" success. Signal deaths fold to the
  128+N convention across the lpt, queue, isolated, and serial worker paths and
  fail the run with a message naming the signal

## v0.9.3 — 2026-07-10

### Fixed

- Parallel discovery no longer hangs when a spec file fails to load in a worker
- Failure reasons now reach the JSON formatter, so parallel runs report full
  failure detail instead of an empty failure record
- JSON event attributes emit in a stable order
- Stray non-object lines in a worker's JSON stream are no longer treated as
  valid events
- Temporary paths are created before workers write to them
- Mocked time no longer drifts backward between reads

## v0.9.2 — 2026-06-24

### Added

- Live coverage progress line when filtering the raw log on a terminal, with a
  percent, a bar, and a rough ETA
- Fallback content on a coverage HTML file page when the source is unavailable

### Changed

- Coverage now defaults to the lighter `MVM_COVERAGE_CONTROL=0` line-hit mode;
  pass `--coverage-counts` for the heavier per-line execution counts

### Fixed

- Environment variable propagation to parallel workers

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
