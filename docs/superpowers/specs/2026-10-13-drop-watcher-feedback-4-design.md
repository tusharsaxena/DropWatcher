# Ka0s Drop Watcher: owner feedback, fourth session (M13)

- **Extends:** `2026-10-11-drop-watcher-compact-mode-design.md` and the earlier specs.
- **Source:** the owner's notes and screenshots, 2026-10-13. The evidence is in
  `docs/superpowers/research/2026-10-13-feedback-4/`.
- **Plan:** `docs/superpowers/plans/2026-10-13-drop-watcher-feedback-4.md`. Items DW-D0..DW-D5, branch
  `feat/2026-10-13-drop-watcher-feedback-4`.
- **Both layouts.** The owner asked that every change that applies to both the full and the compact layout land in
  both. Each section says where it applies.

## 0. Verdict colors and the arrow's place (DW-D0)

**Evidence.** `05-delta-arrows-after-text.png`: the Me and Them cells read `+6 ▲`, with the arrow after the number
at the column's end; Them's colors are inverted (its upgrade amber, `Can't use` green).

**Rule.**
- **One color per verdict, in every column:** upgrade green (`C.TONE.good`), sidegrade yellow (`C.TONE.yellow`, a
  yellow distinct from the gold the headers use), downgrade red (`C.TONE.red`). `Can't use` and `Not wanted` are gray
  (`bad`) and `?` is muted, in Me and Them alike. The Them column is no longer inverted.
- **The arrow before the number:** `▲ +6`, in the full layout's Group drops (Me, Them), My drops (For me) and History
  (Me, Them) tables, and on the detail card's verdict rows. The compact cards already draw the arrow first.
- The number and its arrow share the tone. The column tooltips stop describing the inversion.

## 1. Action buttons colored by whose move it is (DW-D1)

**Evidence.** `04-actions-column-uncolored.png`: Ask, Asked, Traded, Retry, Queued all in one white.

**Owner decision: the Ask button and My drops' buttons.**
- **Your move — red** (`C.TONE.red`): Ask and Retry; on My drops, Offer while no offer for the drop has been sent and
  Announce while it is ready or failed.
- **Waiting on someone else — yellow** (`C.TONE.yellow`, not gold): Asked and Queued; Offered (an offer to a
  member was sent or queued) and Announced or Queued.
- **Done — green** (`C.TONE.good`): Traded on Group drops; on My drops, both buttons once the drop was traded away
  (History outcome `tradedAway`).
- The dash for no action keeps its gray. History's Outcome column is unchanged.
- **Both layouts:** the compact Group drops card's Ask and the compact My drops card's Offer and Announce take the
  same tones; so do the Offer panel's per-member Offer buttons.
- One pure answer (`WC.ActionTone(state)`) gives the tone for every button's state.

## 2. No dismissing (DW-D2)

**Evidence.** `03-dismiss-column.png`: the × column on Group drops.

**Owner decision: remove every way to dismiss or hide a drop.**
- Group drops: the row's × (full), the card's × (compact) and the detail card's `Hide this item`.
- My drops: the row's `Hide` (full and compact). An untradeable drop's actions show only the dash with its reason.
- The session state behind them goes: `NS.State.windowGroup.dismissed`, `NS.State.windowMine.dismissed`,
  `NS.DismissDrop`, `WindowGroup.Dismiss`, `WindowMine.Dismiss`, and the `dismissed` / `you hid it` reason in the My
  drops tab's tooltip. The automatic ask keeps every other reason to hold off; its chat line stops naming dismissal.
- The Group drops Actions column narrows to the Ask button.

## 3. A Type column: what kind of item it is (DW-D3)

**Owner decision.** The column is labelled `Type`. Its values, from the drop's equip location first and then its
armor subclass:

| The drop | Type |
|---|---|
| Head, shoulder, chest, waist, legs, feet, wrist, hands | `Cloth`, `Leather`, `Mail` or `Plate` (the armor subclass) |
| Neck, finger | `Jewelry` |
| Trinket | `Trinkets` |
| Back | `Cloak` (every class wears one, so `Cloth` would mislead) |
| One-hand, two-hand, main hand, off hand, shield, held in off hand, ranged | `Weapons` |
| Anything else (a token, an armor piece with no type, details not loaded) | `–`, its tooltip saying why |

- **Where:** beside Slot wherever Slot is shown: the Group drops and History tables (full), the compact Group drops
  and History cards' second line, and the detail card's chips. My drops shows no Slot and gains no Type.
- Read from `facts.equipLoc` and `facts.subClassID` (the armor subclass ids in `C.ARMOR`), never a localized name.
- Pure: `WC.ArmorType(drop)` answers the cell.

## 4. Gold headers, the search box, and the window's least width (DW-D4)

**Evidence.** `01-full-header-white.png` against `02-loothistory-header-gold.png`; `06-filter-textbox-gap.png`.

**Rule.**
- **Gold column headers** (`C.GOLD`, as Loot History's), on all three full tables. The compact layout has no column
  headers; its group headers are already gold.
- **The search box (full layout)** starts the bar's gap (8px, the gap between the dropdowns) after the Character
  dropdown and ends at the bar's right edge. Both edges are anchored, so it widens and narrows with the window,
  live while sizing. The compact layout already anchors its search box between View and Filters.
- **The least width is the default width.** Neither layout can be sized narrower than its default for a new
  profile; it can be widened and brought back. Full: after D2 and D3, the default width becomes the width at which
  every column of every tab fits with the Item column at its least width, and the filter bar fits with room to type.
  Compact: the least width is its default (380). A stored width under the least is raised to it on load.
- **Tests** pin that at the full layout's least width no tab sheds a column.

## 5. Docs, tests and the bundle (DW-D5)

- **Smoke checks**, owed: verdict colors and arrow order; action tones in every state; no dismiss anywhere; the Type
  column's values; gold headers; the search box tracking a resize; the window refusing to go narrower than default.
- **Docs:** README, ARCHITECTURE, data-flow, module-map, settings-panel where they name dismissal, the inversion,
  the columns or the window bounds.
- **Bundle:** regenerate test-cases and run a fresh automated-test bundle. It needs all four suites, CCN ≤ 15, and no
  authored file over 1000 lines.
