# Ka0s Drop Watcher: owner feedback, second in-game session (M10)

- **Extends:** the v1 spec `2026-10-10-drop-watcher-v1-design.md` and its addenda (the simulator, the UI feedback and
  the sim feedback specs, all dated 2026-10-11).
- **Source:** the owner's Mythic+ run on 2026-10-11 (Den of Nalorakk). The evidence and screenshots are in
  `docs/superpowers/research/2026-10-11-feedback-2/`.
- **Plan:** `docs/superpowers/plans/2026-10-11-drop-watcher-feedback-2.md`. Items DW-A0..DW-A6, branch
  `feat/2026-10-11-drop-watcher-feedback-2`.

## 0. The "missing" Yoke: what happened, and the regression test (DW-A0)

**What the owner saw.** Two Yokes of the Charging Bear dropped, one for Bùnian-Azralon and one for Keghunt-Thrall
(`01-wgl-two-yokes.png`, `03-chat-loot-lines.png`). Group drops showed only Keghunt's, under the header
"Den of Nalorakk · Mythic+ · 5s ago · 1 drop" (`02-group-drops-one-yoke.png`). History showed both
(`04-history-both-yokes.png`).

**Why.** The drop was captured. The default View, Interesting, hid it:
- the Yoke is −4 for you, so it is not an upgrade;
- it is a sidegrade (+0) for Bùnian, so he is not expected to give it away.

The header then counted only the drops still visible, so nothing said a drop was hidden.

**What to do.**
- **A headless regression test** feeds the owner's exact chat lines through the real parser and feed (`03-chat-loot-lines.png`):
  - the accented, cross-realm `Bùnian-Azralon` looting a Yoke;
  - `Keghunt-Thrall` looting an identical Yoke;
  - `Fading Voidwhisper` x50, a reagent;
  - `Amani Ritual Altar`, a non-gear item;
  - the currency and money lines.

  It asserts that both Yokes are separate drops with the right looters, and that the reagent and the altar are filtered
  out by the gear-only and quality rules. Each must appear in the feed's hidden counts under the right reason, not be
  lost.
- **Prove nothing else is dropped silently.** Every receipt the feed refuses or hides is counted by reason. The
  `drops` diagnostics section reports those counts, and `/dw debug` logs each one with its reason under the FEED tag.
- **Group headers count every drop.** While a filter hides some, the header shows `2 drops · 1 shown`, and the
  header's tooltip lists each hidden drop and the filter that hid it.

## 1. View: All by default, and the checkboxes become views (DW-A1)

**FB2-1. All is the default.** The default View is **All**: change the `feed.view` default and the filter bar's seed.
A profile that stored `interesting` explicitly keeps it, because that was the player's choice. A profile that only
inherited the old default gets All.

**FB2-2. One View dropdown replaces the checkboxes.** `Likely tradeable only`, `Usable by me` and `Upgrade for me`
(`05-filter-checkboxes.png`) become values of the View dropdown, and the three checkboxes are removed from the filter
bar. Like Loot History's `Direction: 3 selected`, the View dropdown is **multi-select**: the views combine as AND, and
**All** clears the others. The label reads:
- `View: All` when nothing else is selected;
- the view's name when one is selected;
- `View: n selected` when more are.

The values and their meanings:
- **All:** every drop that passed the situation and quality gates.
- **Interesting:** an upgrade for you, or a drop its looter is likely to give away and that can be traded.
- **Likely tradeable:** the trade estimate is yes or likely.
- **Usable by me:** you can use it, and you have not marked its type as unwanted.
- **Upgrade for me:** an upgrade over what you wear (or your best owned piece).

The settings rows follow. `feed.view` becomes a set. `trade.likelyOnly`, `feed.usableOnly` and `feed.upgradeOnly`
are folded into it by a migration step that keeps each player's current choices. The slash `set` and `get` verbs
and the settings page change to match.

**FB2-3. The View tooltip** is a bullet list, one line per value, in the words above. Each tab grays out the values
it does not use; History, for example, has no "Likely tradeable".

## 2. Item tooltips beside the window, like Loot History (DW-A2)

**FB2-4.** An item tooltip now opens over the window and covers the table (`06-tooltip-over-window.png`). Loot
History anchors its item tooltip to the row with `ANCHOR_RIGHT` (`../LootHistory/modules/BrowserTable.lua`, the
row's `OnEnter`). Because the row spans the window, the tooltip opens beside the window
(`07-loothistory-tooltip-and-filters.png`).

The rule:
- Every item tooltip opens **beside the window**, top-aligned with the hovered row.
- It opens on the right, or on the **left** when there is not enough room on the screen to the right of the window.
- Measure the room: compare the window's right edge, the tooltip width and the screen width, after `Show()`, at the
  UI scale.
- The rule covers all three tabs, the detail card, the equipment columns and the Offer panel.

One shared helper does this, and it goes in the window module beside `WG.SetItemTooltip`.

## 3. Group headers name the party, class-colored (DW-A3)

**FB2-5.** A group header (`08-group-header.png`) also names **every character who was in the group** for that
run or encounter, each colored by class: `Den of Nalorakk · Mythic+ · 6m ago · 2 drops · Tiamât, Keghunt, Bùnian,
Artêmis, Sacrilege`. You come first.

- **How the roster is captured:** each group keeps a roster snapshot when it opens, and the snapshot grows if
  someone joins mid-run. Each entry holds a short name, the realm when it differs from yours, and the class file.
- **Where it is shown:** headers on all three tabs. History keeps the roster with its group in `global.history`.
  Older History groups have no roster and show none.
- **When it is long:** a raid header shows the first few names and `+n`. The tooltip lists everyone, in class color.

## 4. A Character dropdown, like Loot History (DW-A4)

**FB2-6.** Add a `Character` dropdown to the filter bar on all three tabs, like Loot History's
(`09-loothistory-character-dropdown.png`):
- `Character: All` and `Character: Current` come first;
- each character Drop Watcher has a record for comes next, with its class icon and class color;
- it is multi-select, and the label reads `Character: n selected` when several are chosen;
- the default is **Current**.

**Data.**
- Each drop record and each History entry records the character it was **seen by**: name-realm and class.
- History is account-wide, so the dropdown filters it by recorder.
- Group drops and My drops hold this session's drops, which are only ever the current character's. On those tabs the
  dropdown lists only the current character, alongside All. Older History entries without a recorder count as
  "unknown", which only All shows.

## 5. History kept by days, like Loot History (DW-A5)

**FB2-7.** The History footer reads `4 of 20 groups kept, 7 drops` (`10-history-cap.png`). History is capped at
20 groups (`global.history.maxGroups`), which throws away older runs no matter how recent they are. The owner wants
retention by **age**, set in the settings, like Loot History.

**Loot History's precedent.**
- The setting is `settings.retentionDays`, stored at `global.retentionDays`, default 30.
- It is a dropdown of `C.RETENTION_OPTIONS`, and one of its values is "Never" (keep everything).
- It is **account-wide**: a profile switch, copy or reset never changes it.
- Changing it to a shorter window asks for confirmation when that would delete records (`S:OnRetentionChanged`).
- Its schema row is in `../LootHistory/settings/Schema.lua` (the History group).

**The rule for Drop Watcher.**
- **The setting.** Replace the group cap with `Keep history for`: a dropdown of 7, 14, 30, 60, 90 and 180 days, plus
  Never. The default is 30. It is account-wide and is stored in `global.history`, beside the data (never replace that
  table whole).
- **What is pruned.** Groups whose newest entry is older than the window. Pruning runs once per session (at login,
  deferred), and again when the setting changes to a shorter window.
- **Confirmation.** A change that would delete anything asks first: "This deletes n groups (m drops) older than X
  days." Its popup uses `preferredIndex = 3`.
- **A safety ceiling.** A large ceiling on stored drops keeps SavedVariables bounded even under Never, for example
  5,000 drops with the oldest dropped first. It is a constant, not a setting, and diagnostics report it.
- **Migration.** `maxGroups` is retired. A migration step removes it, and nothing is pruned by the migration itself.
- **Footer.** It reads `n groups, m drops · kept for 30 days` (or `kept forever`), plus the storage size if cheap, like
  Loot History's `Database = 315.2 kB`.
- **Clear history** stays, and keeps its confirmation.

## 6. Docs, tests and the bundle (DW-A6)

**Docs.** Update these for every change above:
- the README Usage, covering the View values, the Character dropdown and the header roster;
- ARCHITECTURE;
- schema, plus the migration step;
- settings-panel and module-map;
- smoke-tests, with owed checks for each FB2 item and the regression from §0;
- the retention setting and its migration.

**Tests and bundle.**
- Regenerate test-cases.
- Run a fresh automated-test bundle: four suites, CCN ≤ 15, no authored file over 1000 lines.

## 8. Added while M10 ran (DW-A7..DW-A9)

**FB2-8, the simulation step delay (DW-A7).** Auto-run (`/dw sim run`, the panel's Run all) waits a fixed 3 seconds
between steps (`SC.STEP_DELAY`). The owner wants it shorter and adjustable:
- the default becomes **2 seconds**;
- a new setting, `sim.stepDelay`, labeled "Simulation step delay", runs from 0.5 to 10 seconds in steps of 0.5. It
  sits in a Simulation group on the settings page that fits best, and works with `/dw set sim.stepDelay <n>`;
- a change takes effect from the next step of a running timeline;
- the panel's Run all tooltip names the current delay.

**FB2-9, the table font matches Loot History (DW-A8).** Evidence: `11-font-vs-loothistory.png`. Loot History's table
uses `GameFontHighlightSmall` at its natural size, with 18-pixel rows (`../LootHistory/modules/BrowserTable.lua`,
`ROW_H_DEFAULT = 18`). Drop Watcher forces `window.fontSize = 12` through `SetFont` and uses 24-pixel rows. The changes:
- `window.fontSize`'s default becomes "the template's own size", stored as 0 or nil to mean unchanged;
- the slider keeps a "Default" position;
- the row height default moves as close to 18 pixels as the item icons allow, on all three tabs. My drops keeps the
  extra height its countdown bar needs, but uses the smaller text;
- a value the player stored stays as it is.

**FB2-10, review leftovers worth fixing (DW-A9).** From the M10 review's low findings:
- **My drops groups:** it has no roster headers, while the spec says all three tabs. Group its rows by run or
  encounter with the same header, or record a reasoned deviation if a flat list is clearly better there.
- **Stale docs:** `docs/data-flow.md` and the TOC comment still describe the retired History cap.
- **Pruning when disabled:** the once-per-session prune is skipped when the addon starts disabled. Prune when it is
  enabled later in the session.
- **Tooltip over the Offer panel:** a row tooltip can cover the Offer panel docked beside the window. Place the
  tooltip beside the panel, or on the other side.
- **Stale retention popup:** an old retention popup can re-apply an older choice after a later change that deleted
  nothing. Make the popup act on the latest pending choice only.

## 7. Out of scope

Changing what "Interesting" means. The owner chose All as the default instead, so the rule stays as documented.
