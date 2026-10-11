# Execution plan: Ka0s Drop Watcher v1 review (2026-10-11)

One milestone, run inside plan item DW-62 on `feat/2026-10-10-drop-watcher-v1`. Each task is written
test first, passes the gate (`lua tests/run.lua` all pass, `luacheck .` 0/0, no authored file over
1500 lines) and lands as its own `DW-62: fix review — …` commit.

## Milestone R1: the five behavior fixes and the popup guard

**Done when** every Medium finding (F-001..F-005) and F-006 is fixed with a case that goes red without
the fix, the docs move with the code, and the gate is green at the last commit.

| Task | Role | Findings / changes | Files |
|---|---|---|---|
| R1-1 | lua-feature | F-001, F-004 / C-01..C-04 | `modules/LootFeed.lua`, `modules/Toast.lua`, `core/DropWatcher.lua`, `settings/SchemaRows.lua`, `tests/test_toast.lua`, `tests/test_feed.lua` |
| R1-2 | lua-feature | F-002 / C-05 | `modules/Toast.lua`, `tests/test_toast.lua`, `tests/test_auto_ask.lua` |
| R1-3 | lua-feature | F-003 / C-06 | `modules/Scoring.lua`, `core/Compat.lua`, `tests/test_scoring.lua` |
| R1-4 | lua-feature | F-005 / C-07 | `modules/AutoAsk.lua`, `tests/test_auto_ask.lua` |
| R1-5 | ux-cleanup | F-006 / C-08 | `modules/WindowHistory.lua`, `settings/Schema.lua` |
| R1-6 | docs | C-09 | `docs/ARCHITECTURE.md`, `docs/compat-layer.md`, `docs/data-flow.md`, `docs/module-map.md`, `docs/smoke-tests.md`, `docs/test-cases.md`, `README.md` (badge) |

## Concurrency map

- R1-1 and R1-2 both edit `modules/Toast.lua` and `tests/test_toast.lua`: **serialize** them (R1-1
  first).
- R1-3 and R1-5 touch files disjoint from the rest: **parallelizable**.
- R1-4 edits `modules/AutoAsk.lua` and `tests/test_auto_ask.lua`. R1-2 adds an auto-ask case to the
  same test file: **serialize** R1-2 before R1-4.
- R1-6 follows every code task, since `docs/test-cases.md` is regenerated from the final suite.

One writer works the checkout, so in practice the tasks run in order R1-1 → R1-2 → R1-3 → R1-4 → R1-5,
each with its docs.

## Checkpoints

- After R1-1: the toast suite proves the clear, trim, dismiss and switch paths, and
  `test_disabled` is still green (the removal sink is not a registration).
- After R1-4: `test_disabled` is still green with the two new AutoAsk rows on events it already lists.
- End of R1: the full gate. `docs/test-cases.md` regenerated with `lua tests/run.lua --list` and the
  README `[tests]` badge moved in the same commit as the count change.

## Commits

One commit per task, docs in the same commit as the code they describe:

- `DW-62: fix review — the toast leaves with its drop and with its switch`
- `DW-62: fix review — an empty-slot upgrade toasts and auto-asks`
- `DW-62: fix review — the Pawn adapter waits for PawnIsInitialized`
- `DW-62: fix review — auto-ask lets go of an encounter it left`
- `DW-62: fix review — the confirmations take StaticPopup slot 3`

The review and audit bundles land first, as `DW-62: Add the v1 review and standards audit bundles`.
