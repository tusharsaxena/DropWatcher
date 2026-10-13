# Ka0s Drop Watcher: owner feedback, sixth session (M15) — plan

- **Spec:** `docs/superpowers/specs/2026-10-13-drop-watcher-feedback-6-design.md`; evidence in
  `docs/superpowers/research/2026-10-13-feedback-6/`.
- **Branch:** `feat/2026-10-13-drop-watcher-feedback-5` (M14 unmerged; M15 continues on it). Plan data in this file's
  namesake folder: `items.tsv`, `checkpoints.tsv`, `RESUME.md`, `resume-state.sh`.
- **Execution:** a workflow running the items in order (they share the Drops modules), one agent per item with the
  green gate and a `DW-Fn: …` commit each; then two independent reviewers, a fix pass, the docs sync; then the
  automated-test bundle and a push.

| Id | Title | Depends on | Effort |
|---|---|---|---|
| DW-F0 | Trade window column fits its widest text | — | S |
| DW-F1 | My eq merged into Me, Their eq into Them: `[icon] 321 ▲6` on Drops, History and compact; toggles retired; least width | DW-F0 | L |
| DW-F2 | Offer in cyan wherever it is drawn | DW-F1 | S |
| DW-F3 | (Details) tooltip: per-member rich lines, texture arrows, no wrap; no glyph boxes in any tooltip | DW-F2 | M |
| DW-F4 | Review fixes, docs sync, automated-test bundle, push | DW-F3 | M |

Checkpoints: after DW-F1 (push), after DW-F4 (bundle green, review fixed, push). Then stop for the owner.
