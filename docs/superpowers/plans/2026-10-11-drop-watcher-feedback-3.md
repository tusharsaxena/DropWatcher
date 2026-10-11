# Ka0s Drop Watcher: owner feedback, third session (M11) — plan

- **Spec:** `docs/superpowers/specs/2026-10-11-drop-watcher-feedback-3-design.md`; evidence in
  `docs/superpowers/research/2026-10-11-feedback-3/`.
- **Branch:** `feat/2026-10-11-drop-watcher-feedback-3` (DropWatcher only). Plan data in this folder's namesake
  directory; the workflow is its `orchestration/dw-milestone.workflow.js`. Rules of the run as the v1 plan's.

| Id | Title | Depends on | Effort |
|---|---|---|---|
| DW-B0 | Sim "Loot: 2 drops" vs one shown: root cause; the step says where its drops went; tabs reconcile; regression per scenario | — | M |
| DW-B1 | Filter-bar tooltips above the control (top right, else top left) | DW-B0 | S |
| DW-B2 | Every row tooltip at the row's top right (else top left), all tabs, one helper | DW-B1 | M |
| DW-B3 | Docs sync and automated-test bundle | DW-B2 | S |

Checkpoint: gate and bundle green, review fixed, push. Then stop for the owner's merge go-ahead.
