# Watch mode

Watch mode keeps `behave` running between runs. When a file under `lib/` or `specs/` changes, Behave figures out which spec files are affected and re-runs only those. The rest of the time you read pass/fail output, type a single-letter command, and keep editing.

## Usage

```shell
$ behave --watch
```

The default watched roots are `./lib` and `./specs` when each one exists. To watch additional directories or a custom layout, pass `--watch-path PATH` (repeatable):

```shell
$ behave --watch --watch-path app/ --watch-path test/
```

When `--watch-path` is given at least once, the default `lib/`/`specs/` roots are replaced by your list — pass them explicitly if you still want them.

`--watch` is mutually exclusive with `--bisect`, `--bisect-data`, `--coverage`, `--doc`, and `--parallel`. Combining any of these exits with status `2`.

## Initial run

When you start `--watch`, Behave does a baseline run of every spec file it can see. The exit code of that run does not terminate watch mode — failures are reported and the loop continues. After the initial run, the watch prompt appears:

```text
[behave watch] press r rerun selection, a rerun all, f failed only, q quit
```

## Smart test selection

When a file changes, Behave decides which specs to re-run:

| Change kind                              | What runs                                                                            |
| ---------------------------------------- | ------------------------------------------------------------------------------------ |
| `specs/foo-spec.raku` (matches `*-spec.raku`) | That spec file only.                                                              |
| `lib/Foo.rakumod` or `lib/A/B.rakumod`   | Every spec whose source contains the module's basename (`Foo`) or its joined module path (`A::B`). |
| A `lib/` change that no spec references  | Falls back to every spec file (so you never miss a real failure).                    |
| A removed file                           | Ignored.                                                                             |
| Multiple files in one tick                | Union of all of the above, deduplicated.                                            |

The mapping is intentionally a substring search rather than a parse. It is fast, has no false negatives in the common case, and makes the fallback explicit: if nothing matches, *everything* runs.

## Interactive commands

While the loop is running, type one of the following on its own line and press Enter:

| Command | Effect                                                                                                  |
| ------- | ------------------------------------------------------------------------------------------------------- |
| `r`     | Re-run the last selection (the most recent set of specs, whether triggered by a change or by `a`).      |
| `a`     | Re-run every spec.                                                                                      |
| `f`     | Re-run only previously-failed examples (uses `.behave-failures`; see [Retry and Only-Failures](../retry/retry.md)). |
| `h` / `?` | Re-print the prompt.                                                                                  |
| `q`     | Exit watch mode. The Behave process exits with status `0`.                                              |
| (Enter) | Equivalent to `r`.                                                                                      |

Unknown input prints a warning and re-prints the prompt.

## Forwarding other flags

`--watch` forwards a subset of CLI flags to each spawned subprocess so your filters and formatters stay in effect across re-runs:

- `--format NAME` (unless the default `progress`)
- `--order ORDER` (unless `random`)
- `--seed N` (when `--order=random` and a seed was set)
- `--show-seed` (when set)
- `--verbose`
- `--retry N` (when N > 0)
- `--tag NAME` (repeatable)
- `--exclude-tag NAME` (repeatable)
- `--example PATTERN` (repeatable)

Each subprocess inherits a `BEHAVE_DISABLE_CONFIG=1` environment so it does not re-read `~/.behave` or `./.behave` and conflict with the parent's resolved configuration.

## Implementation notes

- File detection is **mtime + size polling** at `0.25s` intervals. There is no `inotify` / `kqueue` / `FSEvents` dependency. For typical projects (hundreds to a few thousand files) the polling overhead is negligible.
- Watched files are filtered by basename to `.rakumod`, `.raku`, `.rakutest`, and `.pm6`. Hidden directories (`.git`, `.precomp`) are skipped during the walk.
- Each re-run is a **subprocess** (`raku -Ilib bin/behave …`) so user-level `class` / `role` / `enum` declarations from one run cannot collide with the next. This is the same isolation pattern used by `--bisect`, `--coverage`, and `--parallel`.
- The watch loop itself is a single thread. The interactive reader is a `start { }` block that pushes lines into a `Channel`; the main loop drains it non-blocking with `Channel.poll`.

## Limitations

- New file detection requires a poll tick after the file lands on disk — saving and immediately exiting before the next 250 ms tick may miss the event. In practice this is invisible.
- File renames register as one `removed` plus one `added`. Smart selection treats only the `added` half.
- Watch mode does not surface profile / memory / benchmark summaries across runs — each subprocess emits its own. Aggregation across runs is out of scope for v1.
- `--coverage` is incompatible: each subprocess would need its own MoarVM coverage log path and merge step.
- Smart selection is a substring search; if a spec references a module only by a name that does not appear in the file (e.g. only through dynamic dispatch), Behave will not pick it up. Use `--watch-path` and the `a`/`r` commands to cover that case.
