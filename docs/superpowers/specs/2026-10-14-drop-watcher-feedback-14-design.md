# Ka0s Drop Watcher: owner feedback, fourteenth session (M23) — a Lua error in combat

- **Source:** the owner's two BugSack reports, 2026-10-14, in combat when someone else had looted
  (`docs/superpowers/research/2026-10-14-feedback-14/01-lua-errors.txt`).
- **Plan:** item DW-N0 on `feat/2026-10-14-drop-watcher-feedback-13`.

## 0. A secret width in a tooltip's grid (DW-N0)

Hovering a Me or Them cell in combat shows the gear grid (`modules/TipGrid.lua`, feedback-7 spec §3). Its cells
are font strings on a child frame of GameTooltip, and in combat the client answered their
`GetUnboundedStringWidth` with a 12.0 secret number. `widthOf` only checked `type(w) == "number"`, which a secret
number passes, so the width reached `cellOf`'s `w > 0` (`attempt to compare ... a secret number value`) and
`TG.Columns`' `max` (`attempt to perform numeric conversion on a secret number value`). Both are the one bug.

The fix: each read meets `NS.Compat.IsSecret` first. A secret width falls back to the estimate the grid already
uses for an unmeasured string (`TG.CHAR_W` a character); a secret `NumLines` falls back to the reserved rows'
own count. In combat the columns are therefore laid out on the estimate, and out of combat on the measured
widths as before.

Pinned by `test_tip_marks` (`a secret width or line count in combat paints the grid on the estimate`), whose
`type` answers a secret as `number` as the client does (the kit's wrapper answers `table`, which hid this bug
from the suites). Owed in-game check FEED-76.
