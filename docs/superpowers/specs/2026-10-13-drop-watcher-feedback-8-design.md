# Ka0s Drop Watcher: owner feedback, eighth session (M17)

- **Extends:** `2026-10-13-drop-watcher-feedback-7-design.md` (M16) and the earlier specs (design spec §6.1, When to
  show).
- **Source:** the owner's note and screenshots, 2026-10-13. Evidence in
  `docs/superpowers/research/2026-10-13-feedback-8/`: `01-when-to-show-today.png` (each situation a heading with Track,
  Auto-open and a full-width Quality dropdown under it) and `02-loothistory-price-sources.png` (the reference look).
- **Plan:** `docs/superpowers/plans/2026-10-13-drop-watcher-feedback-8.md`. Items DW-H0..DW-H1, on the same unmerged
  branch `feat/2026-10-13-drop-watcher-feedback-5`.

## 0. When to show as a table (DW-H0)

**Rule.** General › When to show keeps its global **Auto-open the window** checkbox at the top, as a schema row. Under
it, the per-situation settings are **one table**, one row per situation (`K.SITUATIONS`, in order), four columns:

| Situation | Track | Auto-open | Quality |
|---|---|---|---|
| the situation's label (`WindowFooter.SituationLabel`) | checkbox, `situations.<key>.track` | checkbox, `situations.<key>.autoOpen` | dropdown, `situations.<key>.quality` (`Use global` and the qualities, as today) |

**The look is Ka0s Loot History's Price sources table** (`../LootHistory/settings/Panel.lua`, `buildAuctionTable`),
without its drag handle, its reorder list and its status icon:
- gold, left-aligned column headers (`GameFontNormalSmall`) in a band above the first row;
- rows of a fixed height, alternating a faint background stripe, the cells' text in `GameFontHighlightSmall`;
- the library's own CheckBox widget (AceGUI `CheckBox`, the panel's gold tick) for Track and Auto-open, and the
  panel's dropdown for Quality, sized to its column;
- a row's disabled states follow today's rules: Auto-open is disabled while the situation is untracked or the global
  Auto-open the window is off; Quality is disabled while the situation is untracked; an untracked row's Situation
  label dims (as Loot History dims an inactive source).
- Hovering a cell shows that row's tooltip (the schema row's label and tooltip, as the rows show today); hovering the
  Situation label shows the situation and what it covers if a tooltip exists for it.

**Still schema-driven.** The three per-situation rows stay in the schema with their paths, defaults, validation and
tooltips; they are marked `skipRender` and drawn by the table, which writes through the schema runtime
(`NS.SchemaRuntime.Set`), so `/dw` get/set, the page's Defaults button, profiles and their announce work unchanged.
The table is a When to show `afterGroup` hook (settings/Pages.lua), as Feed › Quality's readout is; its pure half
(the rows, each cell's value and enabled state) goes in settings/Editors.lua and its widgets in
settings/PageEditors.lua (or a new small settings file if one would pass the 1000-line band).

**Pooled, re-rendered safely.** As Loot History's host: the table's frame and row slots are built once per session
and re-parented to a fresh placeholder on each render of the tab; every value and enabled state is repainted on each
render and after any write (a checkbox toggled, the global Auto-open toggled, Defaults, a profile switch).

**Tests.** The pure rows (labels, values, enabled states across track/global combinations), the painted table (one
row per situation, the four columns, the stripe on alternate rows, a toggle writing its path, the disabled states,
Defaults repainting it), and the schema rows still present and `skipRender`.

## 1. Docs, review and record (DW-H1)

- An independent review of the diff; findings fixed.
- docs/settings-panel.md, docs/schema.md (the `skipRender` rows), README if it describes the page, design readings'
  superseded note on When to show's layout; smoke check FEED-next owed: the table renders, toggles and disables in
  game.
- The automated-test bundle (shared with M16's), `docs/test-cases.md` and the README badge; push.
