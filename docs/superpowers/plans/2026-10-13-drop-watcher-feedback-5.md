# Ka0s Drop Watcher: owner feedback, fifth session (M14) — plan

- **Spec:** `docs/superpowers/specs/2026-10-13-drop-watcher-feedback-5-design.md`; evidence in
  `docs/superpowers/research/2026-10-13-feedback-5/`.
- **Branch:** `feat/2026-10-13-drop-watcher-feedback-5`, cut from the unmerged `feat/2026-10-13-drop-watcher-feedback-4`
  (DropWatcher only). Plan data in this file's namesake folder: `items.tsv`, `checkpoints.tsv`, `RESUME.md`,
  `resume-state.sh` (what has landed, from git).
- **Execution:** a workflow (the owner asked for ultracode) running the items in order, one agent per item, because
  every item touches the same Drops modules and would conflict in parallel. Each agent keeps the green gate
  (`lua tests/run.lua`, `luacheck .` 0/0, both through `ka0s-bounded`) and commits its item as `DW-En: …`. Then an
  independent review, a fix pass, the docs sync and the automated-test bundle.

| Id | Title | Depends on | Effort |
|---|---|---|---|
| DW-E0 | Actions 84px; rows indented under their header with a muted-white chevron before the item; header chevrons gold (full, compact) | — | S |
| DW-E1 | Trade window column on Drops for every drop (countdown + bar, 104px, rows grow); compact line 2 | DW-E0 | M |
| DW-E2 | Own drops always in Drops: Offer (toned), `Yes (2)`, Them/Their eq `(Multiple)` + tooltip, keep? rule, detail card; retire `feed.showOwn` | DW-E1 | L |
| DW-E3 | Tabs Drops + History; the strip and Post under Drops (both layouts); remove WindowMine, CompactMine | DW-E2 | L |
| DW-E4 | Least width recomputed (glyph, Trade window, Actions); shed order pinned; compact re-check | DW-E3 | S |
| DW-E5 | Review fixes, docs sync (superseded notes, FEED-38..), automated-test bundle | DW-E4 | M |

Checkpoints (rows in `checkpoints.tsv`): after DW-E2 (push), after DW-E4 (push), after DW-E5 (gate and bundle green,
review fixed; push). Then stop for the owner's merge go-ahead and the in-game smoke checks.
