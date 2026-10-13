# Ka0s Drop Watcher: owner feedback, fifth session (M14)

- **Extends:** `2026-10-13-drop-watcher-feedback-4-design.md` (M13) and the earlier specs.
- **Source:** the owner's notes and screenshots, 2026-10-13. The evidence is in
  `docs/superpowers/research/2026-10-13-feedback-5/`.
- **Plan:** `docs/superpowers/plans/2026-10-13-drop-watcher-feedback-5.md`. Items DW-E0..DW-E5, branch
  `feat/2026-10-13-drop-watcher-feedback-5` (cut from the unmerged feedback-4 branch).
- **Both layouts.** Every change that applies to both the full and the compact layout lands in both. Each section
  says where it applies.
- **What this supersedes.** The My drops tab (design spec §11.4, board 04; compact spec §3) is retired. Its
  behavior moves into the Group drops tab, renamed **Drops**. Earlier specs' My drops sections stay as history,
  marked superseded by this one.

## 0. Actions wide enough; the expand indicator (DW-E0)

**Evidence.** `01-actions-cramped.png`: `Queued` with its clock icon fills the 64px button edge to edge.
`04-header-chevron.png`: the group header's chevron, which the rows now reuse.

**Rule: the Actions column.**
- The Ask button (and, from DW-E2, the Offer button on your own rows) is 84px wide (`K.ASK_W`), so every state's
  icon and word (`Ask`, `Asked`, `Queued`, `Retry`, `Traded`, `Offer`, `Offered`) fits with room on both sides.
  The column is the button's width. The compact card's button takes the same width.

**Rule: the expand indicator** (owner, revised mid-run: `04-header-chevron.png`; the earlier LootHistory-glyph
idea, `03-…`, was dropped). A click on a Drops row (or a compact card) opens its detail card, and nothing on the
row said so (the only mark was a chevron at the right edge, drawn while the card was open).
- Every Drops row draws the group header's chevron texture (`NS.Icon`, 10x10) at its left edge, before the item
  icon: `chevron-down` while the row is collapsed and `chevron-up` while its detail card is open. It is muted white
  (`C.CHEVRON_ROW`, white at about 55%, as a vertex color) and does not change on hover. The right-edge chevron is
  removed.
- **The group header's chevron is gold** (`C.GOLD` as its vertex color), matching its gold text.
- **Rows read as children of their header:** each drop row (stripe, chevron and every column) is indented
  `K.ROW_INDENT` (12px) from the header's left edge, so the row's chevron sits under the header's text rather than
  under its chevron. The column labels shift with the rows so they still sit over their cells. The detail card
  indents with its row.
- The chevron is not a column: it has no label, no `window.columns` toggle and never sheds. Item's cell starts after
  it and a 4px gap. The least width counts the indent, the chevron and the gap.
- **Compact:** each card is indented the same and draws the same chevron at its left, before the item button,
  centered on line 1; the compact header's chevron is gold too.
- History's rows do not expand, so they draw no chevron and are not indented (their headers' chevrons turn gold,
  as every group header's does).

## 1. A Trade window column for every drop (DW-E1)

**Owner decision: a separate column that works like My drops' Trade window.**
- **Drops gains `tradeWindow`** ("Trade window") between Trade and Actions. Its cell is `MineCells.TradeWindow`:
  the countdown over its 3px bar (`K.BAR_H`); `No limit (BoE)` for a bind-on-equip drop; the short reason
  (`Bonus roll`, `Window passed`, …) when it cannot be traded; `Checking` before an estimate exists.
- **Every drop has one,** not only yours. Another player's drop is always the estimate from when it dropped
  (`~1:42:10`); its tooltip says so. Your own drop is exact once the item is in your bags, as before. The countdown
  and the estimate come from `MC.Countdown`, which already reads `drop.at` when there is no `expiresAt`; the
  tooltip's wording for another player's drop names the looter rather than your bags.
- **104px wide.** The words `ending soon` are no longer drawn in the cell: ending soon is the amber tone and bold
  text, and the tooltip says `Ending soon: …`. The bar turns amber with it, as before.
- **Rows grow by the bar's room,** as My drops' rows did (`window.rowHeight` plus the bar and its gap), so the
  countdown text and the bar never overlap.
- It is a toggled column (`window.columns.tradeWindow`, default on) and sheds after Their eq and before Them.
- Countdowns move each second: the footer ticker and `TradeTimerTick` repaint the Drops tab while any shown row
  has a live countdown (they repainted My drops before).
- **Compact:** line 2's right side shows the countdown and its bar for a drop with one; a drop with none (not
  tradeable, no estimate) keeps the inspect freshness there.

## 2. Your own drops in Drops (DW-E2)

**Owner decisions.** Own drops are always listed (no new View value); the Trade cell counts the upgrades; Them and
Their eq read `(Multiple)`; their tooltip lists every member it would upgrade; Offer replaces Ask; no Announce
button in the table.

- **Always listed.** `feed.showOwn` and its settings row ("Show my own loot in Group drops") are retired. A stored
  value is ignored. The group header's `· n yours on My drops` and `Window.TabContext`'s `onMine` are removed.
- **Trade on your own drop** appends the count of members it upgrades: `Yes (2)`, `Likely (1)`. With none it is
  the bare word. The tooltip adds `Upgrades 2 members: Offer shows who.`
- **Them and Their eq on your own drop** read `(Multiple)` (muted when nobody's upgrade, green when there is at
  least one). Their tooltip lists each member it upgrades, ranked by gain: `Butterz ▲ +11 · wears 276 (Bloodthorn
  Treads)`, from `MC.Candidates` (gain, their worn item and level). With no upgrades it says `Not an upgrade for
  anyone whose gear was read.`, `n checking` while inspects run, and `Nobody else in your group.` solo.
- **The keep? rule stays.** While the drop is an upgrade for you and you have not opened its Offer panel this
  session (`WM.IsRevealed`, moved to a home that survives the tab's removal), the count is not drawn, (Multiple)
  reads `Hidden` and the tooltip says `An upgrade for you: nobody is offered it unless you choose to. Offer shows
  who it would help.`
- **Actions on your own drop: Offer,** which opens the Offer panel (`NS.OfferPanel.Open`) and reveals. It takes
  M13's tones: red until an offer was sent, yellow once offered (sent or queued), green once given away
  (`WM.ToneStates`' offer half). A drop of yours that cannot be traded shows the gray dash with the reason. There is
  no Announce button in the table; Announce to group stays in the Offer panel's footer.
- **The detail card** of your own drop shows Offer in place of Ask, and its Them row reads `(Multiple)` with the
  same tooltip. The Ask-side reason `Your own drop: offer it from My drops.` becomes `Your own drop: Offer shows
  who it would help.`
- **Compact:** line 1's button is Offer on your own card; line 2's trade piece carries the count; line 3's Them
  reads `(Multiple)` with the same tooltip.

## 3. One tab: Drops, with the strip (DW-E3)

**Owner decision: the strip under Drops.**
- **The tabs are Drops and History.** `Window.TABS = { "group", "history" }` (the internal key stays `group`, so
  saved filter state and tests keep their key); its label is `Drops`. A stored active tab of `mine` opens Drops.
- **The strip** (`MC.Summary`: `n tradeable · next 0:08:41` and **Post my tradeables**, `NS.PostTradeables`) sits
  under the Drops table, above the footer, shown only while at least one of your listed drops can be traded. It
  counts your drops the tab lists (its filters apply). **Compact:** the same strip under the cards, shortened
  (`n tradeable · next 0:08:41`, a `Post` button), as compact My drops drew it.
- **Removed:** `modules/WindowMine.lua` and `modules/CompactMine.lua` (and their TOC lines), the `mine` row of
  `WindowFilterBar.HONORS`, the tab's label count and tooltip, My drops' empty states, and their tests. What the
  rest of the addon still uses moves: `WM.ToneStates`, `WM.Reveal`/`IsRevealed` and the strip's painting go to
  the Drops modules (or a small new module if a file would pass the 1000-line band). `MineCells` keeps every pure
  helper the Offer panel, the Trade window column and the strip use; helpers only the old tab used are removed.
- Every locale string and comment that names My drops is reworded or removed.

## 4. The least width (DW-E4)

- Recompute `K.WIDTH = K.MIN_WIDTH` exactly as M13 did: the sum of every default column's width and gaps
  (now with the row indent and chevron, Trade window at 104 and Actions at 84) plus `ITEM_MIN`, the scroll gutter and the
  insets, so no column sheds at the least width on Drops or History. `tests/test_window_group.lua` pins it and
  the shed order (now including `tradeWindow`).
- Compact's least width (`COMPACT_MIN_W`) is re-checked against line 2 with the countdown and bar on the right;
  it grows only if a test shows a piece cut at 380.
- The search box keeps M13's anchors; a stored width below the least is raised by `WC.ClampSize`.

## 5. Docs, review and record (DW-E5)

- An independent review of the branch; its findings fixed.
- README, ARCHITECTURE (module map, tabs, schema, settings, deviations if any), data-flow, module-map, schema,
  settings-panel, testing and smoke-tests synced. Earlier design readings that describe My drops get dated
  `superseded by feedback-5` notes rather than rewrites. New smoke checks FEED-38.. owed for: the row chevron and indent, the gold header chevron, the
  Actions width, the Trade window column on others' drops, own drops' Trade count, (Multiple) tooltip and Offer,
  the strip, the tab strip, the least width, compact line 2.
- The automated-test bundle (`/dev-copilot:wow-automated-tests`), `docs/test-cases.md` and the README badge.

## Out of scope

- History's columns (other than nothing changing there) and the Offer panel's layout.
- A View value for your own drops (the owner declined it).
