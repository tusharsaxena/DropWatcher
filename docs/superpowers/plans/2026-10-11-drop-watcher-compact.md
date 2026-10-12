# Ka0s Drop Watcher: compact mode (M12) — plan

- **Spec:** `docs/superpowers/specs/2026-10-11-drop-watcher-compact-mode-design.md`; reference image in
  `docs/superpowers/research/2026-10-11-compact/`.
- **Branch:** `feat/2026-10-11-drop-watcher-compact`, stacked on `feat/2026-10-11-drop-watcher-feedback-3` (merge
  that first). Plan data in `2026-10-11-drop-watcher-compact/` (items.tsv, resume-state.sh, RESUME.md,
  checkpoints.tsv, orchestration/dw-milestone.workflow.js).
- **Owner run guidelines:** decide without asking unless necessary; branch and commit incrementally; push after
  milestones; never merge without the owner's go-ahead; delete the run's branches, stashes and worktrees after the
  merge; run as ultracode workflows.

| Id | Title | Depends on | Effort |
|---|---|---|---|
| DW-C0 | Mode switch core (window.mode, per-mode geometry, migration, toggle, Layout row, slash, compactInRuns) | — | M |
| DW-C1 | Pure compact layout (CompactCards) | DW-C0 | M |
| DW-C2 | Compact Group drops | DW-C1 | M |
| DW-C3 | Compact My drops and History | DW-C2 | M |
| DW-C4 | Compact chrome (title bar, tabs, filter row + Filters menu, strip, footer) | DW-C3 | M |
| DW-C5 | Test mode, simulator, perf, same-drop-set test | DW-C4 | M |
| DW-C6 | Docs and automated-test bundle | DW-C5 | S |

Checkpoint: gate and bundle green, independent review fixed, push. Then stop for the owner's merge go-ahead.
