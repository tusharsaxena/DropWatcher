# 04 — Execution plan

One adoption, the hourglass (RX-13), in its own commit after the re-vendor commit.

- Tests first (seen red, 13 cases): `tests/test_roll_cells.lua` pins `RC.WAITING_ICON` to
  `ph:hourglass`, its file under `media/icons/phosphor/`, and the count line's `[hourglass]` mark;
  `tests/test_window_pending.lua` the same mark in the Rolling now row and its tooltip;
  `tests/test_mine_cells.lua`, `tests/test_own_drops.lua`, `tests/test_window_group.lua` and
  `tests/test_toast.lua` the Queued state's icon (the shipped-file helper maps `ph:` to `phosphor/`).
- Code: `modules/RollCells.lua` (`WAITING_ICON`), `modules/MineCells.lua` (the Offer and own-offer
  Queued looks), `modules/WindowCells.lua` (the Ask's Queued look), and the comments that name the mark.
- Declaration: `clock` leaves the `LibKa0s icons:` line, and the tag's `tools/prune-icons.lua`
  removes `clock.tga`.
- Gate: both kit profiles 0 failed, luacheck 0/0, lizard silent, and the kit's complexity suite.
