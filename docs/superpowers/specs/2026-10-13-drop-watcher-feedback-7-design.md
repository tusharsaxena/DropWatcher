# Ka0s Drop Watcher: owner feedback, seventh session (M16)

- **Extends:** `2026-10-13-drop-watcher-feedback-6-design.md` (M15) and the earlier specs.
- **Source:** the owner's notes and screenshots, 2026-10-13, after looking at M15 in game. The evidence is in
  `docs/superpowers/research/2026-10-13-feedback-7/`.
- **Owner decisions (asked up front):** the Offer panel's Trade button is **removed**; Scan group, moved beside Post
  my tradeables, **slides into Post's slot** while Post is hidden.
- **Plan:** `docs/superpowers/plans/2026-10-13-drop-watcher-feedback-7.md`. Items DW-G0..DW-G5, on the same unmerged
  branch `feat/2026-10-13-drop-watcher-feedback-5` (M14 and M15 are unmerged; M16 rides with them).
- **Both layouts.** Every change that applies to both the full and the compact layout lands in both; each section
  says where it applies.

## 0. The Offer panel's rows read like the Drops table (DW-G0)

**Evidence.** `01-offer-panel-columns.png`, `08-offer-panel-rows.png`: Member, `Eq -> drop`, a Status pill and two
buttons, a class-colored bar at each row's start. `02-them-column-look.png`: the Them cell the owner wants matched.
`03-offer-trade-button.png`: the second button (Trade), always grayed.

- **One column, `Their eq`,** where `Eq -> drop` and Status were two. Its cell is the Drops table's Them cell look
  (NS.SideCells): the member's worn item icon(s), its item level (`276`, `321/308`), then the verdict glyph and the
  unsigned difference in the verdict tone (`▲19`, `≈0`, `▽4`), glyphs in the monospace face. The words stay words
  where the pill said one: `Can't use` (gray), `…` while checking, `Unavailable` (muted) when nothing could be read,
  `empty` when nothing is worn there. The pill (`+11 UPGRADE`, `EQUAL`, …) is gone; its tooltip text moves into the
  cell's tooltip, which is §3's columnar tooltip plus the pill's explanation.
- **No class bar.** The 3px stripe at each row's start is removed; the member's name keeps its class color.
- **Alternating rows,** as the main window's: every second row draws the same faint stripe (`1, 1, 1, 0.03`) across
  the row, as WindowGroup's and WindowHistory's rows do.
- **The Trade button is removed** (owner decision). Actions holds Offer alone (or the dash with its reason). The
  Actions column's tooltip drops its Trade sentence. `NS.GiveDrop`, `NS.TradeHelper` and their tests stay (the
  slash surface and the trade helper still use them); a helper only the panel's button used (`MC.TradeButton`) is
  removed with its tests.
- The column positions are re-measured for the new set (Member, Their eq, Actions) inside the unchanged 440px panel;
  the Their eq column is at least the Drops table's Them width so `321/308 ▽13` and two icons fit.

## 1. An icon on every action button (DW-G1)

**Evidence.** `04-action-buttons.png`: Traded, Retry, Asked and Queued carry an icon; Ask and Offer do not.

- **Ask** takes `chat` (a whisper to the looter) and **Offer** takes `export` (handing the item out), LibKa0s media
  icons, tinted with the button's tone as the other states' icons are. Offered keeps `confirm`, Queued `clock`,
  Retry `reset`, Traded and Asked `confirm`; Announce to group keeps `speech-bubble`.
- **Everywhere an action button is drawn:** the Drops row, the compact card, the detail card, the Offer panel's
  Offer, and Announce to group. A test walks every look table (WindowCells' ask looks, MineCells' offer and announce
  looks, DetailCells' actions) and fails on a state with no icon.
- The button widths (`K.ASK_W` 84, `PANEL_BTN_W`, the compact button) are re-checked so every icon and word fits;
  `PANEL_BTN_W` grows if `Offered`/`Queued` with an icon do not fit.

## 2. Cells that say more at a glance (DW-G2)

**Evidence.** `07-trade-no-gray.png`, `09-looter-column.png`, `10-details-cell.png`.

- **Trade `No` is red** (`C.TONE.red`), not the gray `bad` tone; on Drops, History (if drawn there), the compact
  card's trade piece and the detail card's Trade row. Yes/Likely stay green, Unknown muted.
- **Your own drop's looter** reads `Name [YOU]`: the name in your class color, ` [YOU]` in gold (`C.GOLD`). On every
  looter text: the Drops and History tables, the compact card, the detail card. When the cell is too narrow the name
  is cut first; `[YOU]` is always drawn (the cell is two FontStrings, or the width check accounts for it).
- **`(Details)` becomes `Upgrade for N`** (green) on your own drop's Them cell (table, compact line 3, detail card),
  `N` the members it upgrades. With none it reads `No upgrades` (muted); under the keep? rule `Hidden`, as before.
- **The Trade cell drops the count:** `Yes (2)` reads `Yes`, `Likely (1)` reads `Likely`. Its tooltip keeps the line
  `Upgrades 2 members: Offer shows who.`

## 3. Columnar tooltips with the table's arrows (DW-G3)

**Evidence.** `05-them-column-arrows.png` (the table's `▲ 12`, `▽ 13`), `06-tooltip-arrow.png` and
`11-details-tooltip.png` (the tooltip's thin texture arrow, the number uncolored, one run-on line),
`12-them-tooltip.png` (Them's tooltip: `Butterz wears`, `Speakeasy Shroud (292)`, then prose).

- **A grid in the tooltip.** A tooltip may carry rows of cells, laid out as columns:
  `[Name]  [Item level]  [Item name]  [Arrow and difference]`. Each column is as wide as its widest cell; columns
  are separated by a fixed gap; the tooltip is at least as wide as the grid. The name is in its class color, the item
  name in its quality color, the item level plain.
- **The table's arrows.** The arrow column draws the same glyphs as the Me/Them cells (`▲`, `▽`, `≈`, from
  WindowCells.GLYPH) in the monospace face (`C.FONT_MONO`), so they render, and **both the glyph and the
  difference** take the verdict tone (green, yellow, red). No texture arrows inside a grid.
- **How.** The tooltip is still GameTooltip (its skin, its placement through NS.RowTooltip). A grid reserves one
  tooltip line per row and draws its cells as FontStrings on a pooled child frame of the tooltip, anchored to those
  lines; `SetMinimumWidth` makes room for the widest row. The pool hides on tooltip hide. The pure side describes a
  grid as data (`{ grid = { { cells… }, … } }` among the tooltip's lines, NS.TipMarks), so suites read it without
  frames; Window's showTooltip paints it. The headless mock records the grid.
- **Where.** Every tooltip that lists worn gear against a drop:
  - your own drop's `Upgrade for N` (table, compact, detail card): one row per member it upgrades, ranked by gain;
  - Them on another player's drop: one row for the looter, `[Looter] [ilvl] [worn item] [▲diff]`;
  - Me: one row for you, `[You] [ilvl] [worn item] [▲diff]`;
  - the Offer panel's Their eq cell: one row for that member.
  Two worn items (rings, trinkets, one-hand weapons) are two rows; the arrow and difference go on the row of the item
  the drop would replace (the lower), the other row's last cell is empty. Nothing worn: the item cell reads `empty`
  (muted).
- **The prose stays, without repeats.** The lines after the grid keep the inspect's age and the verdict's
  explanation; the comparison line the grid now shows (`Item level 295 against 289 (Speakeasy Shroud): +6.`) and the
  `X wears` / `Item (ilvl)` lines are dropped.
- Tooltips with no gear list keep their texture marks (NS.TipMarks.Mark) and any number after such a mark takes the
  mark's tone too.

## 4. The bottom row and the empty state (DW-G4)

**Evidence.** `13-post-and-sort.png`, `14-scan-group-button.png`, `15-empty-state-full.png`,
`16-empty-state-compact.png`.

- **Post my tradeables is the Sort dropdown's size** (its width, `SORT_W`, and the control height) and sits
  directly above it: its right edge on Sort's right edge.
- **Scan group moves from the title bar to the Drops strip,** immediately left of Post my tradeables with an 8px gap,
  the same height. **While Post is hidden** (no drop of yours can be traded) Scan group slides into Post's slot,
  directly above Sort (owner decision). The strip is therefore shown on Drops whenever the full layout is (its
  summary text is empty when you have nothing tradeable). The title bar's restriction badge anchors to the layout
  toggle where it anchored to Scan group. History has no Scan group (`/dw scan` stays).
- **Compact keeps its title-bar Scan group icon** (its strip has no room for a second button); only the full
  layout's moves.
- **The empty state's two buttons are centered as a pair** under the text (`Preview with test data` and
  `Scan group`, a fixed gap between them), in both layouts: today each hangs from the text's center, so the wider
  Preview pushes the pair left.

## 5. Review, docs and record (DW-G5)

- An independent review of M16's diff; findings fixed.
- Docs synced (README, ARCHITECTURE, module-map, data-flow, settings-panel if touched, design readings' superseded
  notes for the Offer panel's columns and Trade button, the title bar's Scan group); smoke checks FEED-56.. owed for
  each section above.
- The automated-test bundle, `docs/test-cases.md` and the README badge; push.

## Out of scope

- The Offer panel's width and dock, the History strip's Clear history, the compact strip's layout.
