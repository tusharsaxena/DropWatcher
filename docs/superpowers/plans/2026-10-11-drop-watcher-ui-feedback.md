# Ka0s Drop Watcher: owner UI feedback (M8) — plan addendum

- **Spec:** `docs/superpowers/specs/2026-10-11-drop-watcher-ui-feedback-design.md`; the owner's screenshots are in
  `docs/superpowers/research/2026-10-11-ui-feedback/`.
- **Extends:** `2026-10-10-drop-watcher-v1.md` (frozen). Its rules of the run, execution model and plan data folder
  apply unchanged; M8 is added as rows in its `items.tsv` and recorded in its `RESUME.md` log.
- **Why:** the owner's first in-game look on 2026-10-11 found a wrong item read in My drops and a list of UI changes.

## Items

| Id | Title | Depends on | Effort |
|---|---|---|---|
| DW-80 | BUG-1 the wrong item read (root cause, most complete link, exact bag read, `drops` diagnostics, `core/ItemRead.lua` shaped for LibKa0s, drafted LibKa0s issue) and BUG-2 the real game tooltip everywhere | — | M |
| DW-81 | Header like Loot History: no logo, centered title, red TEST MODE / SIMULATION text, yellow strip kept | DW-80 | S |
| DW-82 | Filter bar widgets styled like Loot History | DW-81 | S |
| DW-83 | My eq column, Their eq with icons and levels, Usable by me / Upgrade for me filters, the window opens on every eligible drop | DW-82 | M |
| DW-84 | Test mode with real items from the simulator's pool, History test data, no trailing ellipses | DW-83 | M |
| DW-85 | M8 docs sync and a fresh automated-test bundle | DW-84 | S |

## Checkpoint

Gate green, bundle green, independent review fixed, then `checkpoint.sh M8` pushes the branch and notes. Then stop for
the owner's merge go-ahead.
