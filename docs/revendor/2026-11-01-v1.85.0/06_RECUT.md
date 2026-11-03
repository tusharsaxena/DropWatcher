# The re-cut tag

The tag this bundle names at `9776130` moved to `2ad1a50` (FS-REL, the rulings of 2026-11-01 and FS-GATE), and this addon took it by hand in FS-DW-GATE. `libs/LibKa0s/` and `tests/_kit/` are exact copies, apart from the pruned icons. Kit 49 -> 50.

- **Declared by the pair:** `test_skin_values`, `test_skin_switch`. `tests/test_skin_literals.lua` retired into the first: every row it allowed is a kit category now, so the host has no row.
- **Facade:** `S.BarBorder` answers its three, `S.HoverArt` is a no-op. This addon draws no bar and calls neither, so the rulings on bar values and bar border styles reach nothing here. `cover.dim` the same: no cover.
- **Moved with no call changed:** `S.HudFont`'s font object is one per look; two suites read the string's object anew.
- **Adopted:** the tables pass `opts.shadowToken`, and the row signature reads `S.HudShadow("dw.tableShadow")`.
- **Owes nothing:** `NS.FULL_SKIN_KEYS` has no numeric path, so no repair step. The addon calls no `S.Mark` on a pooled AceGUI widget. The off-spec glow draws no shadow: its token `dw.glowOffSpec` stands.
