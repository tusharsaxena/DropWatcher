# Ka0s Drop Watcher: owner feedback, second in-game session (M10) — plan

- **Spec:** `docs/superpowers/specs/2026-10-11-drop-watcher-feedback-2-design.md`; evidence in
  `docs/superpowers/research/2026-10-11-feedback-2/`.
- **Branch:** `feat/2026-10-11-drop-watcher-feedback-2` (DropWatcher only).
- **Plan data:** `2026-10-11-drop-watcher-feedback-2/` (`items.tsv`, `resume-state.sh`, `RESUME.md`,
  `checkpoints.tsv`). The milestone workflow and `checkpoint.sh` are reused from
  `2026-10-10-drop-watcher-v1/orchestration/` with this folder's args (`milestones.json` here).
- **Rules of the run:** as the v1 plan's (git is the only state, every commit gated, tests first for pure logic,
  commits carry the session trailers, push at the checkpoint, merge only on the owner's go-ahead, smoke checks owed).

| Id | Title | Depends on | Effort |
|---|---|---|---|
| DW-A0 | The two-Yoke regression (owner's chat lines through the real parser and feed); every refused or hidden receipt counted by reason; headers say `n drops · m shown` | — | M |
| DW-A1 | View: All by default; the three checkboxes become multi-select View values; bullet tooltip; settings migration | DW-A0 | M |
| DW-A2 | Item tooltips beside the window (right, else left), all tabs | DW-A1 | S |
| DW-A3 | Group headers name the party, class-colored, all tabs; History keeps the roster | DW-A2 | M |
| DW-A4 | Character dropdown like Loot History (All, Current, each character; default Current), all tabs; recorder on drops and History | DW-A3 | M |
| DW-A5 | History kept by days (Keep history for, default 30, account-wide, confirm on shrink, safety ceiling); maxGroups retired by migration | DW-A4 | M |
| DW-A6 | Docs sync and automated-test bundle | DW-A5 | S |

Checkpoint: gate and bundle green, independent review fixed, push the branch and notes. Then stop for the owner's
merge go-ahead.
