# Ka0s Drop Watcher: simulator feedback (M9) — plan addendum

- **Spec:** `docs/superpowers/specs/2026-10-11-drop-watcher-sim-feedback-design.md`; evidence in
  `docs/superpowers/research/2026-10-11-sim-feedback/`.
- **Extends:** `2026-10-10-drop-watcher-v1.md` (frozen); its rules, execution model and plan data folder apply. M9 is
  added as rows in its `items.tsv` and recorded in its `RESUME.md` log.
- **Why:** the owner's first `/dw sim run` left the window empty, and the owner asked for a clickable step panel like
  the MultiMeters perf-run panel.

| Id | Title | Depends on | Effort |
|---|---|---|---|
| DW-90 | A sim run fills the window: every read the simulator answers goes through the seam; end-to-end regression for every scenario under default filters; footer and chat report the run | — | M |
| DW-91 | The simulation step panel (PerfPanel look, clickable steps, run controls, scenario picker); LibKa0s step-panel issue drafted | DW-90 | M |
| DW-92 | M9 docs sync and automated-test bundle | DW-91 | S |

Checkpoint: gate and bundle green, review fixed, `checkpoint.sh M9` pushes. Then stop for the owner's merge go-ahead.
