# Ka0s Drop Watcher: owner feedback, third session (M11)

- **Extends:** `2026-10-11-drop-watcher-feedback-2-design.md` and the earlier specs.
- **Source:** the owner's simulator run and their tooltip notes, 2026-10-11. The evidence is in
  `docs/superpowers/research/2026-10-11-feedback-3/`.
- **Plan:** `docs/superpowers/plans/2026-10-11-drop-watcher-feedback-3.md`. Items DW-B0..DW-B3, branch
  `feat/2026-10-11-drop-watcher-feedback-3`.

## 0. "Loot: 2 drops", but the window shows one (DW-B0)

**Evidence.**
- `01-sim-panel-loot-2-drops.png`: the panel step reads `Loot: 2 drops`.
- `02-window-one-drop.png`: Group drops shows one drop (Lysandra's Vile Vial) under a header reading `1 drop`, and
  the My drops tab shows no count.

**Likely cause, which must be proven before any fix.** Since the sim feedback spec §0, a random burst of two or more
lines always includes one line for **you**. Your own drop belongs on My drops, not Group drops (`feed.showOwn` is off
by default). The My drops tab label counts only your drops that are tradeable (yes or likely), so an untradeable own
drop adds nothing to it.

Use systematic debugging. Reproduce the owner's run headless with a key scenario and a two-line burst, and find out
where the second drop went:
- your own drop on My drops;
- hidden by a gate;
- merged by the de-duplication;
- lost.

Then fix whatever is actually wrong. Whatever the cause, these must hold afterwards:
- **The step says where its drops went.** The panel row and the chat line read `Loot: 2 drops (1 yours)` or
  `Loot: 3 drops (1 yours, 1 hidden)`. The row's tooltip names each drop: its item, its looter, and the tab it is on
  or the gate that hid it.
- **The tabs agree.**
  - The My drops tab label counts all of your drops in the current feed (`My drops · n`), with the tradeable ones
    in its tooltip.
  - A Group drops header whose run also has your own drops adds `· n yours on My drops`, so the totals reconcile
    with the panel.
- **Regression test.** For every scenario, the sum of the drops shown on Group drops, the drops on My drops and the
  hidden drops equals the number of drops the simulator reports for each loot step.

## 1. Dropdown tooltips above the dropdown (DW-B1)

**Evidence.** `03-view-tooltip-over-dropdown.png`: the View tooltip opens over the dropdown it explains and covers it.

**Rule.**
- Every filter-bar control's tooltip anchors **above the control, to its top right**. That means the tooltip's
  `BOTTOMLEFT` sits on the control's `TOPRIGHT` (`ANCHOR_RIGHT` semantics), so it never covers the control or the
  open menu.
- The controls are the View, Quality, Content, Character and Sort dropdowns, the search box, and the footer's Sort.
- When there is no room to the right, it uses `ANCHOR_LEFT` instead.

## 2. Every row tooltip at the row's top right, like Loot History (DW-B2)

**Evidence.**
- `04-cell-tooltip-in-row.png`: a cell's reason tooltip ("For Lysandra: Can't use") opens inside the table, over
  other columns.
- `05-item-tooltip-beside-window.png`: the item tooltip opens beside the window, but lower down.
- `06-loothistory-tooltip-top-right.png`: Loot History anchors its row tooltip with `ANCHOR_RIGHT` on the full-width
  row (`../LootHistory/modules/BrowserTable.lua`, the row's `OnEnter`). The tooltip rises from the **row's top right
  corner**, just outside the window.

**Rule.**
- **Every** tooltip raised from a table row on any of the three tabs uses one placement. That includes:
  - the item tooltip;
  - every cell's reason tooltip: Looter, My eq, Their eq, Me, Them, Trade, the Ask button and the dismiss ×;
  - the group headers;
  - the My drops rows and their Offer and Announce buttons;
  - the History rows.
- **The placement:** the tooltip's `BOTTOMLEFT` sits at the row's `TOPRIGHT`, where the row is the full-width row
  frame (or the window's right edge for a row that does not reach it). The tooltip rises from the row's top-right
  corner, outside the window.
- **When there is no room on the right:** use `BOTTOMRIGHT` at the row's `TOPLEFT`, just outside the window's left
  edge.
- **When the Offer panel is docked:** the docked panel still counts as part of the window, as in DW-A9.
- **One helper for all of it:** DW-A2's `PlaceItemTooltip` becomes the single row-tooltip placement, used by
  `Window.AttachTooltip` for row cells as well as by the item hover.
- **Out of scope:** tooltips outside rows (the title bar, the footer, the settings pages) keep their own anchors,
  apart from the filter bar in §1.

## 3. Docs, tests and the bundle (DW-B3)

- **Smoke checks**, owed: the panel's loot step reconciles with the tabs; dropdown tooltips sit above the dropdown;
  row tooltips sit at the row's top right, on the right or the left.
- **Docs:** README, ARCHITECTURE, data-flow and module-map.
- **Bundle:** regenerate test-cases and run a fresh automated-test bundle. It needs all four suites, CCN ≤ 15, and no
  authored file over 1000 lines.
