# Ka0s Drop Watcher: owner feedback, fourth session (M13) — plan

- **Spec:** `docs/superpowers/specs/2026-10-13-drop-watcher-feedback-4-design.md`; evidence in
  `docs/superpowers/research/2026-10-13-feedback-4/`.
- **Branch:** `feat/2026-10-13-drop-watcher-feedback-4` (DropWatcher only). Plan data in this folder's namesake
  directory. Run inline (no workflow): one item at a time, the green gate (`lua tests/run.lua`, `luacheck .`) before
  each commit.

| Id | Title | Depends on | Effort |
|---|---|---|---|
| DW-D0 | Verdict colors: green up, yellow side, red down in both columns; the arrow before the number | — | S |
| DW-D1 | Action buttons toned by whose move it is: Ask, My drops' Offer and Announce, the Offer panel, both layouts | DW-D0 | M |
| DW-D2 | Remove every dismiss and hide: ×, detail card Hide, My drops Hide, their state | DW-D1 | M |
| DW-D3 | Type column beside Slot (Cloth … Plate, Jewelry, Trinkets, Cloak, Weapons), table, cards, detail card | DW-D2 | M |
| DW-D4 | Gold column headers; search box anchored after Character to the right edge; least width = default width | DW-D3 | M |
| DW-D5 | Docs sync and automated-test bundle | DW-D4 | S |

Checkpoint: gate and bundle green, review fixed. Then stop for the owner's merge go-ahead.
