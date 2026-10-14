# Ka0s Drop Watcher: owner feedback, seventh session (M16) — plan

- **Spec:** `docs/superpowers/specs/2026-10-13-drop-watcher-feedback-7-design.md`; evidence in
  `docs/superpowers/research/2026-10-13-feedback-7/`.
- **Branch:** `feat/2026-10-13-drop-watcher-feedback-5` (M14 and M15 unmerged; M16 continues on it). Plan data in this
  file's namesake folder: `items.tsv`, `checkpoints.tsv`, `RESUME.md`, `resume-state.sh`.
- **Execution:** a workflow running the items in order (they share the Drops and Offer panel modules), one agent per
  item with the green gate and a `DW-Gn: …` commit each; then two independent reviewers, a fix pass, the docs sync;
  then the automated-test bundle and a push.

| Id | Title | Depends on | Effort |
|---|---|---|---|
| DW-G0 | Offer panel: Their eq column in the Them look, no class bar, alternating rows, Trade button removed | — | M |
| DW-G1 | An icon on every action button (Ask `chat`, Offer `export`), every view | DW-G0 | S |
| DW-G2 | Trade No red; looter `Name [YOU]`; `Upgrade for N` replaces (Details); Trade count dropped | DW-G1 | M |
| DW-G3 | Columnar gear tooltips with the table's mono arrows, tone on glyph and number | DW-G2 | L |
| DW-G4 | Scan group beside Post my tradeables above Sort; empty-state buttons centered | DW-G3 | M |
| DW-G5 | Review fixes, docs sync, automated-test bundle, push | DW-G4 | M |

Checkpoints: after DW-G2 (push), after DW-G5 (bundle green, review fixed, push). Then stop for the owner.
