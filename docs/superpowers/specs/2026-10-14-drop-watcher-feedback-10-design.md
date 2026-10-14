# Ka0s Drop Watcher: owner feedback, tenth session (M19) — arrow, Offer icon, compact cards, Sort

- **Extends:** feedback-4 spec §0 (one tone per verdict), feedback-7 spec §1 (action icons) and §4 (the Drops strip),
  feedback-6 spec §1 (compact line 3), feedback-5 spec §1 (the compact countdown).
- **Source:** the owner's note and screenshots, 2026-10-14: `docs/superpowers/research/2026-10-14-feedback-10/`
  (`01-hollow-down-arrow.png`, `02-offer-icon.png`, `03-compact-cards.png`, `04-strip-sort.png`) and the icon
  options the owner chose from (`05-offer-icon-options.png`).
- **Plan:** items DW-J0..DW-J4 on `feat/2026-10-13-drop-watcher-feedback-5`.

## 0. The downgrade glyph is filled (DW-J0)

`▽` (hollow) becomes `▼` (filled, U+25BC; JetBrains Mono has it) wherever a verdict is drawn as a glyph: the
tables' Me/Them cells, the compact cards, the toast, the Offer panel and the tooltips' grids (`WindowCells.GLYPH`,
the one source, and every literal). The texture marks (TipMarks' `arrow-down`, the detail card and the legends)
are already a solid arrow and stay as they are.

## 1. The Offer icon is `external-link` (DW-J1)

Every Offer button (the Drops row and compact card for your own drop, the detail card, the Offer panel's rows)
wears LibKa0s' `external-link` (a box with an arrow leaving it: handing the item out) in place of
`export`. Its other states keep their icons. The owner first chose E `transfer` from twelve catalog options, then
moved Offer to D `external-link` once it showed the detail card's Trade already wore `transfer` (the two must
never share a mark). Trade keeps `transfer`, which is also the texture legends' sidegrade mark.

## 2. The compact card, simplified (DW-J2)

| Line | Drops card | History card |
|---|---|---|
| 1 | `292 Item name` — the item level (its tone as today) **before** the name, one gap, no right-aligned ilvl; the inspect freshness **in brackets right after the name** (`(2m)`, `(cached)`, `(…)`, dimmed), left out entirely where there is nothing to say (no `–` placeholder; owner's second note, `06-fresh-and-dash.png`) | `292 Item name` — the same; the outcome right-aligned, as today |
| 2 | looter · slot · type · trade; **the action button right-aligned** (Ask, Offer, their states); with no action the slot is **left empty** (no `–`; its reason tooltip still over it) | unchanged (the time right-aligned) |
| 3 | `You 321/308 ▼13   Them 298/296 ⊘ Can't use` — `You` and `Them` in **gold**; Them follows You's last piece after a fixed gap (CG.HALVES_GAP), not at half the card's width | the same |

- **The trade window indicator is gone from the compact card** (the countdown text and its bar). The full table's
  Trade window column, the strip's next expiry and the detail card keep it; the compact card's per-second tick has
  nothing left to move (the strip's ticker stays).
- The item name is cut first; the item level and the bracketed freshness always show (NS.WindowRows.MarkedWidth,
  as the looter's ` [YOU]`).
- The compact least width is recomputed from the new lines (the countdown no longer sets it).

## 3. Sort beside the strip's buttons (DW-J3)

- **Full layout, Drops:** the strip reads, right-aligned, `[Post my tradeables] [Scan group] [Sort]`, Sort at the
  strip's right edge (its inset), Scan group DS.GAP left of it, Post DS.GAP left of Scan group. While Post is
  hidden, Scan group stays beside Sort and nothing slides.
- **Full layout, History:** the same Sort control sits at the right edge of History's strip, beside Clear history
  (owner's choice: Sort in the same place on both tabs). It follows the active tab: the window parents and
  anchors it to the shown tab's strip (WindowFooter.AnchorSort).
- **The footer no longer holds Sort**; its health segments keep their line.
- **Compact:** unchanged (Sort lives in the Filters panel).

## 4. Docs and record (DW-J4)
- README, ARCHITECTURE, module-map, data-flow, testing, smoke-tests (owed FEED-67..70), design readings' superseded
  notes; review fixes; the automated-test bundle.
